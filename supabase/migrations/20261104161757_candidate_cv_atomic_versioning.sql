create or replace function public.register_candidate_cv(p_file_path text,p_original_file_name text,p_mime_type text,p_file_size_bytes bigint)
returns public.cv_versions language plpgsql security definer set search_path=''
as $$
declare v_user_id uuid:=auth.uid();v_version integer;v_row public.cv_versions%rowtype;
begin
 if v_user_id is null then raise exception 'Authentication required' using errcode='42501';end if;
 if p_mime_type not in('application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document') or p_file_size_bytes<1 or p_file_size_bytes>10485760 or p_file_path not like v_user_id::text||'/%' then raise exception 'Invalid CV metadata' using errcode='22023';end if;
 perform 1 from public.candidate_profiles where user_id=v_user_id for update;
 if not found then raise exception 'Candidate profile missing' using errcode='P0002';end if;
 select coalesce(max(version_number),0)+1 into v_version from public.cv_versions where user_id=v_user_id;
 update public.cv_versions set is_active=false where user_id=v_user_id and is_active;
 insert into public.cv_versions(user_id,version_number,file_path,original_file_name,mime_type,file_size_bytes,is_active)
 values(v_user_id,v_version,p_file_path,p_original_file_name,p_mime_type,p_file_size_bytes,true) returning * into v_row;
 return v_row;
end;$$;
revoke all on function public.register_candidate_cv(text,text,text,bigint) from public,anon;
grant execute on function public.register_candidate_cv(text,text,text,bigint) to authenticated;
create or replace function public.set_candidate_active_cv(p_cv_id uuid)
returns public.cv_versions language plpgsql security definer set search_path=''
as $$
declare v_user_id uuid:=auth.uid();v_row public.cv_versions%rowtype;
begin
 if v_user_id is null then raise exception 'Authentication required' using errcode='42501';end if;
 perform 1 from public.candidate_profiles where user_id=v_user_id for update;
 if not found then raise exception 'Candidate profile missing' using errcode='P0002';end if;
 update public.cv_versions set is_active=false where user_id=v_user_id and is_active;
 update public.cv_versions set is_active=true where id=p_cv_id and user_id=v_user_id returning * into v_row;
 if not found then raise exception 'CV version not found' using errcode='P0002';end if;
 return v_row;
end;$$;
revoke all on function public.set_candidate_active_cv(uuid) from public,anon;
grant execute on function public.set_candidate_active_cv(uuid) to authenticated;
