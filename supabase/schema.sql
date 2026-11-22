-- =====================================================================
-- Collab: skema database Supabase
-- Cara pakai: Supabase Dashboard > SQL Editor > paste semua > Run (sekali).
--
-- Prinsip keamanan:
--   * Semua tabel pakai RLS. Aplikasi Flutter cukup pakai anon key.
--   * Aksi sensitif (buat/gabung kelompok, absen QR, hitung skor) lewat
--     fungsi RPC, bukan insert langsung ke tabel.
--   * Status "approved/rejected" tugas hanya bisa berubah lewat validasi
--     anggota lain, bukan diedit sendiri.
-- =====================================================================

-- ---------- ENUM ----------
create type public.member_role   as enum ('leader', 'member', 'lecturer');
create type public.task_status   as enum ('todo', 'in_progress', 'submitted', 'approved', 'rejected');
create type public.evidence_type as enum ('file', 'image', 'link');

-- ---------- TABEL ----------
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null check (char_length(full_name) between 1 and 100),
  nrp        text check (nrp ~ '^[0-9]{5,20}$'),
  avatar_url text check (char_length(avatar_url) <= 1000),
  created_at timestamptz not null default now()
);

create table public.groups (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (char_length(name) between 1 and 100),
  course_name   text check (char_length(course_name) <= 100),
  -- 6 karakter untuk mahasiswa, 8 karakter untuk dosen (panjang beda = tidak bentrok)
  invite_code   text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
  lecturer_code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  created_by    uuid not null references public.profiles (id),
  created_at    timestamptz not null default now()
);

create table public.group_members (
  group_id  uuid not null references public.groups (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  role      public.member_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create unique index one_leader_per_group on public.group_members (group_id) where role = 'leader';
create index group_members_user_idx on public.group_members (user_id);

create table public.tasks (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups (id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 150),
  description  text check (char_length(description) <= 2000),
  assignee_id  uuid references public.profiles (id) on delete set null,
  weight       smallint not null default 2 check (weight in (1, 2, 3)), -- 1 ringan, 2 sedang, 3 berat
  deadline     timestamptz,
  status       public.task_status not null default 'todo',
  created_by   uuid not null default auth.uid() references public.profiles (id),
  created_at   timestamptz not null default now(),
  submitted_at timestamptz,
  approved_at  timestamptz
);
create index tasks_group_idx    on public.tasks (group_id);
create index tasks_assignee_idx on public.tasks (assignee_id);

create table public.task_evidences (
  id           uuid primary key default gen_random_uuid(),
  task_id      uuid not null references public.tasks (id) on delete cascade,
  submitted_by uuid not null default auth.uid() references public.profiles (id),
  type         public.evidence_type not null,
  url          text not null check (char_length(url) <= 1000), -- link, atau path di bucket "evidences"
  note         text check (char_length(note) <= 500),
  created_at   timestamptz not null default now(),
  check (type <> 'link' or url ~* '^https?://')
);
create index task_evidences_task_idx on public.task_evidences (task_id);

create table public.task_validations (
  task_id      uuid not null references public.tasks (id) on delete cascade,
  validator_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  approved     boolean not null,
  comment      text check (char_length(comment) <= 500),
  created_at   timestamptz not null default now(),
  primary key (task_id, validator_id)
);

create table public.meetings (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups (id) on delete cascade,
  title      text not null check (char_length(title) between 1 and 150),
  starts_at  timestamptz not null default now(),
  created_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now()
);
create index meetings_group_idx on public.meetings (group_id);

-- Token QR dipisah supaya anggota tidak bisa membacanya lalu absen dari rumah.
-- Tabel ini tidak punya policy sama sekali: hanya bisa diakses lewat fungsi.
create table public.meeting_tokens (
  meeting_id uuid primary key references public.meetings (id) on delete cascade,
  token      text not null unique,
  expires_at timestamptz not null
);

create table public.meeting_attendances (
  meeting_id    uuid not null references public.meetings (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  checked_in_at timestamptz not null default now(),
  primary key (meeting_id, user_id)
);

create table public.peer_reviews (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.groups (id) on delete cascade,
  reviewer_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  reviewee_id uuid not null references public.profiles (id) on delete cascade,
  week_start  date not null default date_trunc('week', now())::date,
  score       smallint not null check (score between 1 and 5),
  comment     text check (char_length(comment) <= 500),
  created_at  timestamptz not null default now(),
  unique (group_id, reviewer_id, reviewee_id, week_start),
  check (reviewer_id <> reviewee_id)
);
create index peer_reviews_reviewee_idx on public.peer_reviews (group_id, reviewee_id);

-- ---------- FUNGSI BANTU (dipakai di policy) ----------
-- security definer supaya policy tidak saling memanggil RLS (infinite recursion).
create function public.is_member(gid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members
                 where group_id = gid and user_id = auth.uid());
$$;

-- Anggota mahasiswa (ketua/anggota), dosen tidak termasuk.
create function public.is_student(gid uuid, uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members
                 where group_id = gid and user_id = uid and role in ('leader', 'member'));
$$;

create function public.is_leader(gid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members
                 where group_id = gid and user_id = auth.uid() and role = 'leader');
$$;

-- Untuk policy storage: folder pertama = group_id. Aman dari path yang bukan uuid.
create function public.is_member_folder(folder text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  if folder is null or folder !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return public.is_member(folder::uuid);
end;
$$;

-- ---------- TRIGGER ----------
-- Profil otomatis dibuat saat user daftar.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, left(coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
                                split_part(new.email, '@', 1), 'Pengguna'), 100));
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Menjaga aturan main tugas: detail hanya diubah ketua, submit wajib ada bukti,
-- status approved/rejected hanya dari validasi, tugas approved terkunci.
create function public.guard_task_update() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(current_setting('collab.internal', true), '') = 'on' then
    return new;
  end if;

  if old.status = 'approved' then
    raise exception 'Tugas yang sudah disetujui terkunci dan tidak bisa diubah';
  end if;

  -- Kolom yang tidak boleh diubah langsung dari aplikasi.
  new.group_id     := old.group_id;
  new.created_by   := old.created_by;
  new.created_at   := old.created_at;
  new.submitted_at := old.submitted_at;
  new.approved_at  := old.approved_at;

  if not public.is_leader(old.group_id)
     and (new.title, new.description, new.assignee_id, new.weight, new.deadline)
         is distinct from (old.title, old.description, old.assignee_id, old.weight, old.deadline) then
    raise exception 'Hanya ketua yang bisa mengubah detail tugas';
  end if;

  if new.status is distinct from old.status then
    if new.status in ('approved', 'rejected') then
      raise exception 'Status disetujui/ditolak hanya bisa lewat validasi anggota lain';
    end if;

    if new.status = 'submitted' then
      if not exists (select 1 from public.task_evidences where task_id = new.id) then
        raise exception 'Upload bukti kerja dulu sebelum submit';
      end if;
      new.submitted_at := now();
      -- Submit ulang = putaran validasi baru.
      delete from public.task_validations where task_id = new.id;
    end if;
  end if;

  return new;
end;
$$;
create trigger guard_task_update before update on public.tasks
  for each row execute function public.guard_task_update();

-- Setelah anggota memvalidasi: 1 penolakan = rejected,
-- cukup persetujuan (2 orang, atau 1 kalau kelompok cuma 2) = approved.
create function public.apply_task_validation() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_group     uuid;
  v_students  int;
  v_required  int;
  v_approvals int;
  v_rejected  boolean;
begin
  select group_id into v_group from public.tasks where id = new.task_id;

  select count(*) into v_students
  from public.group_members
  where group_id = v_group and role in ('leader', 'member');

  v_required := greatest(1, least(2, v_students - 1));

  select count(*) filter (where approved), coalesce(bool_or(not approved), false)
  into v_approvals, v_rejected
  from public.task_validations
  where task_id = new.task_id;

  perform set_config('collab.internal', 'on', true);
  if v_rejected then
    update public.tasks set status = 'rejected', approved_at = null where id = new.task_id;
  elsif v_approvals >= v_required then
    update public.tasks set status = 'approved', approved_at = now() where id = new.task_id;
  end if;
  perform set_config('collab.internal', 'off', true);

  return null;
end;
$$;
create trigger apply_task_validation after insert on public.task_validations
  for each row execute function public.apply_task_validation();

-- ---------- RPC (dipanggil dari Flutter: supabase.rpc('nama_fungsi', params: {...})) ----------
create function public.create_group(p_name text, p_course text default null)
returns public.groups
language plpgsql security definer set search_path = '' as $$
declare
  g public.groups;
begin
  if auth.uid() is null then
    raise exception 'Harus login dulu';
  end if;
  if p_name is null or char_length(trim(p_name)) not between 1 and 100 then
    raise exception 'Nama kelompok wajib diisi (maks. 100 karakter)';
  end if;

  insert into public.groups (name, course_name, created_by)
  values (trim(p_name), nullif(trim(p_course), ''), auth.uid())
  returning * into g;

  insert into public.group_members (group_id, user_id, role)
  values (g.id, auth.uid(), 'leader');

  return g;
end;
$$;

create function public.join_group(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_code  text := upper(trim(coalesce(p_code, '')));
  v_group uuid;
  v_role  public.member_role;
begin
  if auth.uid() is null then
    raise exception 'Harus login dulu';
  end if;
  if v_code !~ '^[0-9A-F]{6}$' and v_code !~ '^[0-9A-F]{8}$' then
    raise exception 'Format kode tidak valid';
  end if;

  if char_length(v_code) = 6 then
    select id into v_group from public.groups where invite_code = v_code;
    v_role := 'member';
  else
    select id into v_group from public.groups where lecturer_code = v_code;
    v_role := 'lecturer';
  end if;

  if v_group is null then
    raise exception 'Kode kelompok tidak ditemukan';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (v_group, auth.uid(), v_role)
  on conflict (group_id, user_id) do nothing;

  return v_group;
end;
$$;

-- Dipanggil aplikasi ketua tiap ~30 detik. Token lama hangus, jadi foto QR
-- yang dikirim ke teman yang tidak hadir cepat tidak berlaku.
create function public.get_meeting_qr(p_meeting uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_group uuid;
  v_token text := replace(gen_random_uuid()::text, '-', '');
begin
  select group_id into v_group from public.meetings where id = p_meeting;
  if v_group is null or not public.is_leader(v_group) then
    raise exception 'Hanya ketua yang bisa menampilkan QR rapat';
  end if;

  insert into public.meeting_tokens (meeting_id, token, expires_at)
  values (p_meeting, v_token, now() + interval '60 seconds')
  on conflict (meeting_id) do update
    set token = excluded.token, expires_at = excluded.expires_at;

  -- Ketua yang menampilkan QR otomatis tercatat hadir.
  insert into public.meeting_attendances (meeting_id, user_id)
  values (p_meeting, auth.uid())
  on conflict do nothing;

  return v_token;
end;
$$;

create function public.check_in(p_token text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_meeting uuid;
  v_group   uuid;
begin
  if auth.uid() is null then
    raise exception 'Harus login dulu';
  end if;
  if p_token is null or p_token !~ '^[0-9a-f]{32}$' then
    raise exception 'QR tidak valid';
  end if;

  select mt.meeting_id, m.group_id into v_meeting, v_group
  from public.meeting_tokens mt
  join public.meetings m on m.id = mt.meeting_id
  where mt.token = p_token and mt.expires_at > now();

  if v_meeting is null then
    raise exception 'QR sudah kedaluwarsa, minta ketua menampilkan ulang';
  end if;
  if not public.is_student(v_group, auth.uid()) then
    raise exception 'Kamu bukan anggota kelompok ini';
  end if;

  insert into public.meeting_attendances (meeting_id, user_id)
  values (v_meeting, auth.uid())
  on conflict do nothing;

  return v_meeting;
end;
$$;

-- Feedback yang kamu terima, tanpa nama pemberi (anonim).
create function public.my_peer_feedback(gid uuid)
returns table (week_start date, score smallint, comment text)
language sql stable security definer set search_path = '' as $$
  select pr.week_start, pr.score, pr.comment
  from public.peer_reviews pr
  where pr.group_id = gid and pr.reviewee_id = auth.uid()
  order by pr.week_start desc, pr.score;
$$;

-- Skor kontribusi. Rumus dijelaskan di docs/skor-kontribusi.md.
create function public.contribution_scores(gid uuid)
returns table (
  user_id           uuid,
  full_name         text,
  task_points       numeric,
  meetings_attended int,
  peer_avg          numeric,
  validations_given int,
  contribution_pct  numeric,
  fair_share_pct    numeric,
  needs_attention   boolean
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not public.is_member(gid) then
    raise exception 'Kamu bukan anggota kelompok ini';
  end if;

  return query
  with members as (
    select gm.user_id, p.full_name
    from public.group_members gm
    join public.profiles p on p.id = gm.user_id
    where gm.group_id = gid and gm.role in ('leader', 'member')
  ),
  n as (
    select count(*)::numeric as cnt from members
  ),
  t as ( -- poin tugas: bobot x faktor tepat waktu (telat = 0.7)
    select m.user_id,
           coalesce(sum(tk.weight * case when tk.deadline is null or tk.submitted_at <= tk.deadline
                                         then 1.0 else 0.7 end), 0) as pts
    from members m
    left join public.tasks tk
      on tk.assignee_id = m.user_id and tk.group_id = gid and tk.status = 'approved'
    group by m.user_id
  ),
  a as ( -- jumlah rapat yang dihadiri
    select m.user_id, count(ma.meeting_id)::numeric as att
    from members m
    left join public.meeting_attendances ma
      on ma.user_id = m.user_id
     and ma.meeting_id in (select id from public.meetings where group_id = gid)
    group by m.user_id
  ),
  r as ( -- rata-rata peer review; belum direview = netral 3
    select m.user_id, coalesce(avg(pr.score), 3)::numeric as rev
    from members m
    left join public.peer_reviews pr
      on pr.reviewee_id = m.user_id and pr.group_id = gid
    group by m.user_id
  ),
  v as ( -- jumlah validasi yang diberikan ke tugas orang lain
    select m.user_id, count(tv.task_id)::numeric as val
    from members m
    left join public.task_validations tv
      on tv.validator_id = m.user_id
     and tv.task_id in (select id from public.tasks where group_id = gid)
    group by m.user_id
  ),
  combined as (
    select m.user_id, m.full_name, t.pts, a.att, r.rev, v.val
    from members m
    join t using (user_id)
    join a using (user_id)
    join r using (user_id)
    join v using (user_id)
  ),
  totals as (
    select sum(pts) as s_t, sum(att) as s_a, sum(rev) as s_r, sum(val) as s_v from combined
  ),
  scored as (
    -- Tiap komponen = porsi orang itu dari total kelompok.
    -- Kalau total komponen masih 0 (belum ada data), dibagi rata.
    select c.*,
           100 * (
             0.60 * case when tot.s_t > 0 then c.pts / tot.s_t else 1 / n.cnt end +
             0.15 * case when tot.s_a > 0 then c.att / tot.s_a else 1 / n.cnt end +
             0.15 * case when tot.s_r > 0 then c.rev / tot.s_r else 1 / n.cnt end +
             0.10 * case when tot.s_v > 0 then c.val / tot.s_v else 1 / n.cnt end
           ) as pct,
           100 / n.cnt as fair
    from combined c
    cross join totals tot
    cross join n
  )
  select s.user_id,
         s.full_name,
         round(s.pts, 2),
         s.att::int,
         round(s.rev, 2),
         s.val::int,
         round(s.pct, 1),
         round(s.fair, 1),
         s.pct < 0.5 * s.fair
  from scored s
  order by s.pct desc;
end;
$$;

-- Fungsi RPC hanya untuk user yang sudah login.
revoke execute on function
  public.create_group(text, text), public.join_group(text), public.get_meeting_qr(uuid),
  public.check_in(text), public.my_peer_feedback(uuid), public.contribution_scores(uuid)
from public, anon;
grant execute on function
  public.create_group(text, text), public.join_group(text), public.get_meeting_qr(uuid),
  public.check_in(text), public.my_peer_feedback(uuid), public.contribution_scores(uuid)
to authenticated;

-- Fungsi trigger tidak boleh dipanggil lewat API sama sekali.
revoke execute on function
  public.handle_new_user(), public.guard_task_update(), public.apply_task_validation()
from public, anon, authenticated;

-- Fungsi bantu RLS: hanya user login (dibutuhkan saat policy dievaluasi).
revoke execute on function
  public.is_member(uuid), public.is_student(uuid, uuid), public.is_leader(uuid), public.is_member_folder(text)
from public, anon;
grant execute on function
  public.is_member(uuid), public.is_student(uuid, uuid), public.is_leader(uuid), public.is_member_folder(text)
to authenticated;

-- ---------- ROW LEVEL SECURITY ----------
alter table public.profiles            enable row level security;
alter table public.groups              enable row level security;
alter table public.group_members       enable row level security;
alter table public.tasks               enable row level security;
alter table public.task_evidences      enable row level security;
alter table public.task_validations    enable row level security;
alter table public.meetings            enable row level security;
alter table public.meeting_tokens      enable row level security;
alter table public.meeting_attendances enable row level security;
alter table public.peer_reviews        enable row level security;

-- profiles: lihat diri sendiri + teman sekelompok, edit diri sendiri.
create policy "profiles_select" on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.group_members me
      join public.group_members other on other.group_id = me.group_id
      where me.user_id = auth.uid() and other.user_id = profiles.id
    )
  );
create policy "profiles_update" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- groups: dibuat lewat create_group(); lihat kalau anggota; ketua boleh edit/hapus.
create policy "groups_select" on public.groups for select to authenticated
  using (public.is_member(id));
create policy "groups_update" on public.groups for update to authenticated
  using (public.is_leader(id)) with check (public.is_leader(id));
create policy "groups_delete" on public.groups for delete to authenticated
  using (public.is_leader(id));

-- group_members: gabung lewat join_group(); keluar sendiri atau dikeluarkan ketua.
create policy "members_select" on public.group_members for select to authenticated
  using (public.is_member(group_id));
create policy "members_delete" on public.group_members for delete to authenticated
  using (role <> 'leader' and (user_id = auth.uid() or public.is_leader(group_id)));

-- tasks
create policy "tasks_select" on public.tasks for select to authenticated
  using (public.is_member(group_id));
create policy "tasks_insert" on public.tasks for insert to authenticated
  with check (
    public.is_student(group_id, auth.uid())
    and created_by = auth.uid()
    and status = 'todo' and submitted_at is null and approved_at is null
    and (assignee_id is null or public.is_student(group_id, assignee_id))
  );
create policy "tasks_update" on public.tasks for update to authenticated
  using (public.is_leader(group_id) or assignee_id = auth.uid())
  with check (assignee_id is null or public.is_student(group_id, assignee_id));
create policy "tasks_delete" on public.tasks for delete to authenticated
  using (public.is_leader(group_id) and status <> 'approved');

-- task_evidences: hanya PIC tugas yang upload; boleh dihapus selama tugas belum
-- disubmit. Setelah masuk validasi bukti dikunci (jejak kerja).
create policy "evidences_select" on public.task_evidences for select to authenticated
  using (exists (select 1 from public.tasks t
                 where t.id = task_id and public.is_member(t.group_id)));
create policy "evidences_insert" on public.task_evidences for insert to authenticated
  with check (
    submitted_by = auth.uid()
    and exists (select 1 from public.tasks t
                where t.id = task_id and t.assignee_id = auth.uid()
                  and t.status in ('todo', 'in_progress', 'rejected'))
  );
create policy "evidences_delete" on public.task_evidences for delete to authenticated
  using (
    submitted_by = auth.uid()
    and exists (select 1 from public.tasks t
                where t.id = task_id and t.assignee_id = auth.uid()
                  and t.status in ('todo', 'in_progress', 'rejected'))
  );

-- task_validations: anggota lain (bukan PIC) memvalidasi tugas yang sedang submitted.
create policy "validations_select" on public.task_validations for select to authenticated
  using (exists (select 1 from public.tasks t
                 where t.id = task_id and public.is_member(t.group_id)));
create policy "validations_insert" on public.task_validations for insert to authenticated
  with check (
    validator_id = auth.uid()
    and exists (select 1 from public.tasks t
                where t.id = task_id
                  and t.status = 'submitted'
                  and t.assignee_id is distinct from auth.uid()
                  and public.is_student(t.group_id, auth.uid()))
  );

-- meetings: ketua membuat rapat; semua anggota bisa lihat.
-- Edit/hapus hanya selama rapat belum mulai (rapat yang sudah terlaksana dikunci).
create policy "meetings_select" on public.meetings for select to authenticated
  using (public.is_member(group_id));
create policy "meetings_insert" on public.meetings for insert to authenticated
  with check (public.is_leader(group_id) and created_by = auth.uid());
create policy "meetings_update" on public.meetings for update to authenticated
  using (public.is_leader(group_id) and starts_at > now())
  with check (public.is_leader(group_id) and starts_at > now());
create policy "meetings_delete" on public.meetings for delete to authenticated
  using (public.is_leader(group_id) and starts_at > now());
revoke update on public.meetings from authenticated;
grant update (title, starts_at) on public.meetings to authenticated;

-- meeting_tokens: sengaja TANPA policy (hanya lewat get_meeting_qr / check_in).

-- meeting_attendances: masuk hanya lewat check_in(); semua anggota bisa lihat.
create policy "attendances_select" on public.meeting_attendances for select to authenticated
  using (exists (select 1 from public.meetings m
                 where m.id = meeting_id and public.is_member(m.group_id)));

-- peer_reviews: isi/ubah/hapus untuk minggu ini saja; hanya pemberi yang bisa lihat review miliknya.
-- Penerima melihat lewat my_peer_feedback() (tanpa nama pemberi).
create policy "reviews_select" on public.peer_reviews for select to authenticated
  using (reviewer_id = auth.uid());
create policy "reviews_insert" on public.peer_reviews for insert to authenticated
  with check (
    reviewer_id = auth.uid()
    and week_start = date_trunc('week', now())::date
    and public.is_student(group_id, auth.uid())
    and public.is_student(group_id, reviewee_id)
  );
-- Ubah/hapus hanya review minggu ini; minggu lalu sudah terkunci.
create policy "reviews_update" on public.peer_reviews for update to authenticated
  using (reviewer_id = auth.uid() and week_start = date_trunc('week', now())::date)
  with check (reviewer_id = auth.uid() and week_start = date_trunc('week', now())::date);
create policy "reviews_delete" on public.peer_reviews for delete to authenticated
  using (reviewer_id = auth.uid() and week_start = date_trunc('week', now())::date);
revoke update on public.peer_reviews from authenticated;
grant update (score, comment) on public.peer_reviews to authenticated;

-- ---------- STORAGE (bukti kerja) ----------
-- Path upload wajib: {group_id}/{task_id}/{nama_file}
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('evidences', 'evidences', false, 10485760, array[
  'image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'application/zip',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
]);

create policy "evidences_read" on storage.objects for select to authenticated
  using (bucket_id = 'evidences' and public.is_member_folder((storage.foldername(name))[1]));
create policy "evidences_upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'evidences' and public.is_member_folder((storage.foldername(name))[1]));

-- ---------- REALTIME ----------
-- Progres tugas & validasi update live di semua HP anggota (tetap mengikuti RLS).
alter publication supabase_realtime add table public.tasks, public.task_validations;
-- Supaya event hapus ikut membawa group_id, jadi filter realtime per kelompok tetap jalan.
alter table public.tasks replica identity full;
