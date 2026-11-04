create or replace function public.delete_candidate_cv(p_cv_id uuid)
returns text language plpgsql security definer set search_path=''
as $$
declare v_user_id uuid:=auth.uid();v_path text;v_was_active boolean;
begin
 if v_user_id is null then raise exception 'Authentication required' using errcode='42501';end if;
 perform 1 from public.candidate_profiles where user_id=v_user_id for update;
 if not found then raise exception 'Candidate profile missing' using errcode='P0002';end if;
 select file_path,is_active into v_path,v_was_active from public.cv_versions where id=p_cv_id and user_id=v_user_id for update;
 if not found then raise exception 'CV version not found' using errcode='P0002';end if;
 delete from public.cv_versions where id=p_cv_id and user_id=v_user_id;
 if v_was_active then update public.cv_versions set is_active=true where id=(select id from public.cv_versions where user_id=v_user_id order by version_number desc limit 1);end if;
 return v_path;
end;$$;
revoke all on function public.delete_candidate_cv(uuid) from public,anon;
grant execute on function public.delete_candidate_cv(uuid) to authenticated;