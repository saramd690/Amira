-- Keep candidate identity and privacy rows in sync with Supabase Auth.
create or replace function public.handle_new_candidate_user()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  insert into public.candidate_profiles(user_id,first_name)
  values(new.id,nullif(trim(coalesce(new.raw_user_meta_data->>'first_name','')),''))
  on conflict(user_id) do nothing;
  insert into public.candidate_privacy_settings(user_id)
  values(new.id) on conflict(user_id) do nothing;
  return new;
end;
$$;
revoke all on function public.handle_new_candidate_user() from public,anon,authenticated;
drop trigger if exists on_auth_user_created_candidate on auth.users;
create trigger on_auth_user_created_candidate after insert on auth.users
for each row execute function public.handle_new_candidate_user();
insert into public.candidate_profiles(user_id,first_name)
select id,nullif(trim(coalesce(raw_user_meta_data->>'first_name','')),'') from auth.users
on conflict(user_id) do nothing;
insert into public.candidate_privacy_settings(user_id)
select id from auth.users on conflict(user_id) do nothing;
