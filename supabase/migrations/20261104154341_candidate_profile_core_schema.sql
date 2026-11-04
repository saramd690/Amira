-- Candidate schema; applied to the linked Supabase project.
create extension if not exists pgcrypto with schema extensions;
create table public.candidate_profiles(user_id uuid primary key references auth.users(id) on delete cascade,first_name text,last_name text,phone text,date_of_birth date,location text,headline text,summary text,university text,faculty text,specialization text,profile_completion integer not null default 0 check(profile_completion between 0 and 100),availability_status text not null default 'available' check(availability_status in('available','notice_period','unavailable')),notice_period_days integer check(notice_period_days is null or notice_period_days between 0 and 365),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.educations(id uuid primary key default extensions.gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,institution text not null,degree text,field_of_study text,start_date date,end_date date,is_current boolean not null default false,grade text,description text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(end_date is null or start_date is null or end_date>=start_date));
create table public.experiences(id uuid primary key default extensions.gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,company_name text not null,job_title text not null,employment_type text,location text,start_date date,end_date date,is_current boolean not null default false,description text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(end_date is null or start_date is null or end_date>=start_date));
create table public.languages(id uuid primary key default extensions.gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,language_name text not null,proficiency_level text not null check(proficiency_level in('beginner','elementary','intermediate','upper_intermediate','advanced','proficient','native')),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(user_id,language_name));
create table public.certificates(id uuid primary key default extensions.gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,name text not null,issuing_organization text,issue_date date,expiry_date date,credential_id text,credential_url text,description text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(expiry_date is null or issue_date is null or expiry_date>=issue_date));
create table public.projects(id uuid primary key default extensions.gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,name text not null,description text,project_url text,repository_url text,start_date date,end_date date,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(end_date is null or start_date is null or end_date>=start_date));
create table public.cv_versions(id uuid primary key default extensions.gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,version_number integer not null check(version_number>0),file_path text not null unique,original_file_name text not null,mime_type text not null check(mime_type in('application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document')),file_size_bytes bigint not null check(file_size_bytes>0 and file_size_bytes<=10485760),is_active boolean not null default false,uploaded_at timestamptz not null default now(),unique(user_id,version_number),check(file_path like user_id::text||'/%'));
create unique index cv_versions_one_active_per_user on public.cv_versions(user_id) where is_active;
create table public.candidate_privacy_settings(user_id uuid primary key references auth.users(id) on delete cascade,profile_visibility text not null default 'private' check(profile_visibility in('private','recruiters','public')),allow_cv_download boolean not null default false,show_contact_information boolean not null default false,show_current_employer boolean not null default true,updated_at timestamptz not null default now());
create table public.candidate_availability_history(id uuid primary key default extensions.gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,availability_status text not null check(availability_status in('available','notice_period','unavailable')),notice_period_days integer check(notice_period_days is null or notice_period_days between 0 and 365),changed_at timestamptz not null default now());
create or replace function public.set_updated_at() returns trigger language plpgsql set search_path='' as $$ begin new.updated_at=now();return new;end;$$;
create or replace function public.calculate_candidate_profile_completion(p_user_id uuid) returns integer language plpgsql security definer set search_path='' as $$ declare p public.candidate_profiles%rowtype;s integer:=0;begin select * into p from public.candidate_profiles where user_id=p_user_id;if not found then return 0;end if;if nullif(trim(coalesce(p.first_name,'')),'') is not null and nullif(trim(coalesce(p.last_name,'')),'') is not null and nullif(trim(coalesce(p.phone,'')),'') is not null and nullif(trim(coalesce(p.headline,'')),'') is not null and nullif(trim(coalesce(p.summary,'')),'') is not null then s:=s+20;end if;if nullif(trim(coalesce(p.university,'')),'') is not null and nullif(trim(coalesce(p.faculty,'')),'') is not null and nullif(trim(coalesce(p.specialization,'')),'') is not null then s:=s+20;end if;if exists(select 1 from public.educations where user_id=p_user_id) then s:=s+15;end if;if exists(select 1 from public.experiences where user_id=p_user_id) then s:=s+15;end if;if exists(select 1 from public.languages where user_id=p_user_id) then s:=s+10;end if;if exists(select 1 from public.certificates where user_id=p_user_id) then s:=s+5;end if;if exists(select 1 from public.projects where user_id=p_user_id) then s:=s+5;end if;if exists(select 1 from public.cv_versions where user_id=p_user_id) then s:=s+10;end if;return least(s,100);end;$$;
revoke all on function public.calculate_candidate_profile_completion(uuid) from public,anon,authenticated;
create or replace function public.refresh_candidate_profile_completion() returns trigger language plpgsql security definer set search_path='' as $$ declare uid uuid;begin if tg_op='DELETE' then uid:=old.user_id;else uid:=new.user_id;end if;update public.candidate_profiles set profile_completion=public.calculate_candidate_profile_completion(uid),updated_at=now() where user_id=uid;if tg_op='DELETE' then return old;else return new;end if;end;$$;
revoke all on function public.refresh_candidate_profile_completion() from public,anon,authenticated;
create or replace function public.record_candidate_availability_change() returns trigger language plpgsql security definer set search_path='' as $$ begin if tg_op='INSERT' then insert into public.candidate_availability_history(user_id,availability_status,notice_period_days) values(new.user_id,new.availability_status,new.notice_period_days);return new;elsif new.availability_status is distinct from old.availability_status or new.notice_period_days is distinct from old.notice_period_days then insert into public.candidate_availability_history(user_id,availability_status,notice_period_days) values(new.user_id,new.availability_status,new.notice_period_days);end if;return new;end;$$;
revoke all on function public.record_candidate_availability_change() from public,anon,authenticated;

create index educations_user_id_idx on public.educations(user_id);
create index experiences_user_id_idx on public.experiences(user_id);
create index languages_user_id_idx on public.languages(user_id);
create index certificates_user_id_idx on public.certificates(user_id);
create index projects_user_id_idx on public.projects(user_id);
create index cv_versions_user_id_idx on public.cv_versions(user_id);
create index availability_history_user_changed_idx on public.candidate_availability_history(user_id,changed_at desc);

create trigger candidate_profiles_updated_at before update on public.candidate_profiles for each row execute function public.set_updated_at();
create trigger educations_updated_at before update on public.educations for each row execute function public.set_updated_at();
create trigger experiences_updated_at before update on public.experiences for each row execute function public.set_updated_at();
create trigger languages_updated_at before update on public.languages for each row execute function public.set_updated_at();
create trigger certificates_updated_at before update on public.certificates for each row execute function public.set_updated_at();
create trigger projects_updated_at before update on public.projects for each row execute function public.set_updated_at();
create trigger privacy_updated_at before update on public.candidate_privacy_settings for each row execute function public.set_updated_at();
create trigger candidate_availability_history_trigger after insert or update of availability_status,notice_period_days on public.candidate_profiles for each row execute function public.record_candidate_availability_change();

create trigger completion_profile_trigger after insert or update of first_name,last_name,phone,headline,summary,university,faculty,specialization on public.candidate_profiles for each row execute function public.refresh_candidate_profile_completion();
create trigger completion_education_trigger after insert or update or delete on public.educations for each row execute function public.refresh_candidate_profile_completion();
create trigger completion_experience_trigger after insert or update or delete on public.experiences for each row execute function public.refresh_candidate_profile_completion();
create trigger completion_language_trigger after insert or update or delete on public.languages for each row execute function public.refresh_candidate_profile_completion();
create trigger completion_certificate_trigger after insert or update or delete on public.certificates for each row execute function public.refresh_candidate_profile_completion();
create trigger completion_project_trigger after insert or update or delete on public.projects for each row execute function public.refresh_candidate_profile_completion();
create trigger completion_cv_trigger after insert or update or delete on public.cv_versions for each row execute function public.refresh_candidate_profile_completion();

alter table public.candidate_profiles enable row level security;
alter table public.educations enable row level security;
alter table public.experiences enable row level security;
alter table public.languages enable row level security;
alter table public.certificates enable row level security;
alter table public.projects enable row level security;
alter table public.cv_versions enable row level security;
alter table public.candidate_privacy_settings enable row level security;
alter table public.candidate_availability_history enable row level security;

create policy "Candidates manage own profile" on public.candidate_profiles for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Candidates manage own education" on public.educations for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Candidates manage own experience" on public.experiences for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Candidates manage own languages" on public.languages for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Candidates manage own certificates" on public.certificates for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Candidates manage own projects" on public.projects for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Candidates manage own CV metadata" on public.cv_versions for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Candidates manage own privacy settings" on public.candidate_privacy_settings for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Candidates read own availability history" on public.candidate_availability_history for select to authenticated using((select auth.uid())=user_id);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('candidate-cvs','candidate-cvs',false,10485760,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document']);
create policy "Candidates upload own CV files" on storage.objects for insert to authenticated with check(bucket_id='candidate-cvs' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Candidates read own CV files" on storage.objects for select to authenticated using(bucket_id='candidate-cvs' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Candidates update own CV files" on storage.objects for update to authenticated using(bucket_id='candidate-cvs' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='candidate-cvs' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Candidates delete own CV files" on storage.objects for delete to authenticated using(bucket_id='candidate-cvs' and (storage.foldername(name))[1]=(select auth.uid())::text);

grant select,insert,update,delete on public.candidate_profiles to authenticated;
grant select,insert,update,delete on public.educations to authenticated;
grant select,insert,update,delete on public.experiences to authenticated;
grant select,insert,update,delete on public.languages to authenticated;
grant select,insert,update,delete on public.certificates to authenticated;
grant select,insert,update,delete on public.projects to authenticated;
grant select,insert,update,delete on public.cv_versions to authenticated;
grant select,insert,update,delete on public.candidate_privacy_settings to authenticated;
grant select on public.candidate_availability_history to authenticated;
