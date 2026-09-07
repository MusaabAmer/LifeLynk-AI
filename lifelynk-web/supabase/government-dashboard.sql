CREATE OR REPLACE FUNCTION public.verify_organization(p_organization_id uuid,p_status public.verification_status,p_notes text DEFAULT NULL)
RETURNS public.organizations LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_org public.organizations; v_user uuid; v_now timestamptz:=now(); v_notes text:=NULLIF(trim(coalesce(p_notes,'')),'');
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'You are not authenticated.'; END IF;
 IF NOT (public.is_government_admin() OR public.is_super_admin()) THEN RAISE EXCEPTION 'You do not have permission to review organizations.'; END IF;
 IF p_status NOT IN ('VERIFIED'::public.verification_status,'REJECTED'::public.verification_status) THEN RAISE EXCEPTION 'Invalid organization verification status.'; END IF;
 IF p_status='REJECTED'::public.verification_status AND length(coalesce(v_notes,''))<5 THEN RAISE EXCEPTION 'A rejection reason is required.'; END IF;
 UPDATE public.organizations SET verification_status=p_status,verified_at=CASE WHEN p_status='VERIFIED'::public.verification_status THEN v_now ELSE NULL END,verified_by=CASE WHEN p_status='VERIFIED'::public.verification_status THEN auth.uid() ELSE NULL END,verification_notes=v_notes,updated_at=v_now WHERE id=p_organization_id AND deleted_at IS NULL AND verification_status='PENDING'::public.verification_status RETURNING * INTO v_org;
 IF NOT FOUND THEN RAISE EXCEPTION 'Organization was not found, deleted, or has already been reviewed.'; END IF;
 SELECT os.user_id INTO v_user FROM public.organization_staff os JOIN public.users u ON u.id=os.user_id WHERE os.organization_id=p_organization_id AND os.deleted_at IS NULL AND u.is_active=true ORDER BY os.is_primary DESC,os.created_at ASC LIMIT 1;
 INSERT INTO public.audit_logs(id,user_id,action,entity_type,entity_id,description,created_at) VALUES(gen_random_uuid(),auth.uid(),CASE WHEN p_status='VERIFIED'::public.verification_status THEN 'VERIFY_ORGANIZATION' ELSE 'REJECT_ORGANIZATION' END,'ORGANIZATION',p_organization_id,CASE WHEN p_status='VERIFIED'::public.verification_status THEN 'Organization "'||v_org.name||'" was verified by a government administrator.' ELSE 'Organization "'||v_org.name||'" was rejected by a government administrator. Reason: '||coalesce(v_notes,'No reason provided.') END,v_now);
 IF v_user IS NOT NULL THEN INSERT INTO public.notifications(id,user_id,title,message,notification_type,is_read,created_at) VALUES(gen_random_uuid(),v_user,CASE WHEN p_status='VERIFIED'::public.verification_status THEN 'Organization Verified' ELSE 'Organization Verification Rejected' END,CASE WHEN p_status='VERIFIED'::public.verification_status THEN 'Your organization "'||v_org.name||'" has been verified by LifeLynk AI.' ELSE 'Your organization "'||v_org.name||'" was rejected. Reason: '||coalesce(v_notes,'Please contact the government administrator.') END,CASE WHEN p_status='VERIFIED'::public.verification_status THEN 'success' ELSE 'warning' END,false,v_now); END IF;
 RETURN v_org;
END; $$;
REVOKE ALL ON FUNCTION public.verify_organization(uuid,public.verification_status,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_organization(uuid,public.verification_status,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.verify_organization(uuid,public.verification_status,text) TO authenticated;
