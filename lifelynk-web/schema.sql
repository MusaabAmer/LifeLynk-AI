SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE SCHEMA IF NOT EXISTS "public";

ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."organization_type" AS ENUM (
    'HOSPITAL',
    'BLOOD_BANK'
);

ALTER TYPE "public"."organization_type" OWNER TO "postgres";


CREATE TYPE "public"."verification_status" AS ENUM (
    'PENDING',
    'VERIFIED',
    'REJECTED'
);

ALTER TYPE "public"."verification_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_role"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT r.name
    FROM public.users u
    JOIN public.roles r
      ON r.id = u.role_id
    WHERE u.id = auth.uid()
      AND u.deleted_at IS NULL
      AND u.is_active = true
    LIMIT 1;
$$;


ALTER FUNCTION "public"."current_user_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_auth_user_verified"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF
    OLD.email_confirmed_at IS NULL
    AND NEW.email_confirmed_at IS NOT NULL
  THEN
    UPDATE public.users
    SET
      is_verified = true,
      updated_at = NOW()
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_auth_user_verified"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  selected_role text;
  selected_role_id uuid;
BEGIN

  /*
   * Only allow public registration to create these roles.
   *
   * Even if somebody manually sends:
   *
   * role = SUPER_ADMIN
   *
   * it will NOT be accepted here.
   */
  selected_role :=
    CASE
      WHEN NEW.raw_user_meta_data ->> 'registration_role'
        IN (
          'PATIENT',
          'DONOR',
          'HOSPITAL_ADMIN',
          'BLOOD_BANK_ADMIN'
        )
      THEN NEW.raw_user_meta_data ->> 'registration_role'

      ELSE 'PATIENT'
    END;


  /*
   * Find the corresponding role.
   */
  SELECT id
  INTO selected_role_id
  FROM public.roles
  WHERE name = selected_role
  LIMIT 1;


  /*
   * Safety check.
   */
  IF selected_role_id IS NULL THEN
    RAISE EXCEPTION
      'Registration role % does not exist',
      selected_role;
  END IF;


  /*
   * Create the application user.
   */
  INSERT INTO public.users (
    id,
    role_id,
    email,
    full_name,
    phone_number,
    is_active,
    is_verified,
    last_login_at,
    created_at,
    updated_at,
    deleted_at
  )
  VALUES (
    NEW.id,
    selected_role_id,
    lower(trim(NEW.email)),
    COALESCE(
      NULLIF(
        trim(
          NEW.raw_user_meta_data ->> 'full_name'
        ),
        ''
      ),
      split_part(NEW.email, '@', 1)
    ),
    NULL,
    true,
    false,
    NULL,
    now(),
    now(),
    NULL
  )
  ON CONFLICT (id)
  DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    updated_at = now(),
    deleted_at = NULL;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_government_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT public.current_user_role() = 'GOVERNMENT_ADMIN';
$$;


ALTER FUNCTION "public"."is_government_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_organization_admin"("p_organization_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.organization_staff os
        JOIN public.users u
          ON u.id = os.user_id
        JOIN public.roles r
          ON r.id = u.role_id
        WHERE os.organization_id = p_organization_id
          AND os.user_id = auth.uid()
          AND os.deleted_at IS NULL
          AND u.deleted_at IS NULL
          AND u.is_active = true
          AND r.name IN (
              'HOSPITAL_ADMIN',
              'BLOOD_BANK_ADMIN'
          )
    );
$$;


ALTER FUNCTION "public"."is_organization_admin"("p_organization_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_organization_member"("p_organization_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.organization_staff os
        WHERE os.organization_id = p_organization_id
          AND os.user_id = auth.uid()
          AND os.deleted_at IS NULL
    );
$$;


ALTER FUNCTION "public"."is_organization_member"("p_organization_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_super_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT public.current_user_role() = 'SUPER_ADMIN';
$$;


ALTER FUNCTION "public"."is_super_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_organization"("p_user_id" "uuid", "p_city_id" "uuid", "p_organization_type" "public"."organization_type", "p_organization_name" character varying, "p_registration_number" character varying, "p_phone" character varying, "p_email" character varying, "p_address" character varying, "p_latitude" double precision, "p_longitude" double precision, "p_hospital_type" character varying DEFAULT NULL::character varying, "p_hospital_license_number" character varying DEFAULT NULL::character varying, "p_emergency_service" boolean DEFAULT false, "p_blood_storage_available" boolean DEFAULT false, "p_total_beds" integer DEFAULT NULL::integer, "p_icu_available" boolean DEFAULT false, "p_blood_bank_license_number" character varying DEFAULT NULL::character varying, "p_storage_capacity" integer DEFAULT NULL::integer, "p_cold_storage_available" boolean DEFAULT false, "p_blood_processing_available" boolean DEFAULT false, "p_operating_hours" character varying DEFAULT NULL::character varying) RETURNS TABLE("organization_id" "uuid", "organization_name" character varying, "organization_type" "public"."organization_type", "verification_status" "public"."verification_status")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_organization_id uuid;
BEGIN

    /*
     * ---------------------------------------------------------
     * 1. VERIFY CITY
     * ---------------------------------------------------------
     */

    IF NOT EXISTS (
        SELECT 1
        FROM public.cities
        WHERE id = p_city_id
          AND deleted_at IS NULL
          AND is_active = true
    ) THEN
        RAISE EXCEPTION 'INVALID_CITY';
    END IF;


    /*
     * ---------------------------------------------------------
     * 2. VERIFY APPLICATION USER
     * ---------------------------------------------------------
     */

    IF NOT EXISTS (
        SELECT 1
        FROM public.users
        WHERE id = p_user_id
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'APPLICATION_USER_NOT_FOUND';
    END IF;


    /*
     * ---------------------------------------------------------
     * 3. CREATE ORGANIZATION
     * ---------------------------------------------------------
     */

    INSERT INTO public.organizations (
        city_id,
        organization_type,
        name,
        registration_number,
        phone,
        email,
        address,
        latitude,
        longitude,
        verification_status
    )
    VALUES (
        p_city_id,
        p_organization_type,
        trim(p_organization_name),
        NULLIF(trim(p_registration_number), ''),
        trim(p_phone),
        NULLIF(lower(trim(p_email)), ''),
        trim(p_address),
        p_latitude,
        p_longitude,
        'PENDING'
    )
    RETURNING id
    INTO v_organization_id;


    /*
     * ---------------------------------------------------------
     * 4. CREATE HOSPITAL OR BLOOD BANK DETAILS
     * ---------------------------------------------------------
     */

    IF p_organization_type = 'HOSPITAL' THEN

        IF NULLIF(trim(p_hospital_type), '') IS NULL THEN
            RAISE EXCEPTION 'HOSPITAL_TYPE_REQUIRED';
        END IF;

        IF NULLIF(trim(p_hospital_license_number), '') IS NULL THEN
            RAISE EXCEPTION 'HOSPITAL_LICENSE_REQUIRED';
        END IF;

        INSERT INTO public.hospitals (
            organization_id,
            hospital_type,
            license_number,
            emergency_service,
            blood_storage_available,
            total_beds,
            icu_available
        )
        VALUES (
            v_organization_id,
            trim(p_hospital_type),
            trim(p_hospital_license_number),
            p_emergency_service,
            p_blood_storage_available,
            p_total_beds,
            p_icu_available
        );

    ELSIF p_organization_type = 'BLOOD_BANK' THEN

        IF NULLIF(trim(p_blood_bank_license_number), '') IS NULL THEN
            RAISE EXCEPTION 'BLOOD_BANK_LICENSE_REQUIRED';
        END IF;

        INSERT INTO public.blood_banks (
            organization_id,
            license_number,
            storage_capacity,
            cold_storage_available,
            blood_processing_available,
            operating_hours
        )
        VALUES (
            v_organization_id,
            trim(p_blood_bank_license_number),
            p_storage_capacity,
            p_cold_storage_available,
            p_blood_processing_available,
            NULLIF(trim(p_operating_hours), '')
        );

    ELSE

        RAISE EXCEPTION 'INVALID_ORGANIZATION_TYPE';

    END IF;


    /*
     * ---------------------------------------------------------
     * 5. CREATE PRIMARY ORGANIZATION STAFF
     * ---------------------------------------------------------
     */

    INSERT INTO public.organization_staff (
        organization_id,
        user_id,
        is_primary
    )
    VALUES (
        v_organization_id,
        p_user_id,
        true
    );


    /*
     * ---------------------------------------------------------
     * 6. RETURN CREATED ORGANIZATION
     * ---------------------------------------------------------
     */

    RETURN QUERY
    SELECT
        o.id,
        o.name,
        o.organization_type,
        o.verification_status
    FROM public.organizations o
    WHERE o.id = v_organization_id;

END;
$$;


ALTER FUNCTION "public"."register_organization"("p_user_id" "uuid", "p_city_id" "uuid", "p_organization_type" "public"."organization_type", "p_organization_name" character varying, "p_registration_number" character varying, "p_phone" character varying, "p_email" character varying, "p_address" character varying, "p_latitude" double precision, "p_longitude" double precision, "p_hospital_type" character varying, "p_hospital_license_number" character varying, "p_emergency_service" boolean, "p_blood_storage_available" boolean, "p_total_beds" integer, "p_icu_available" boolean, "p_blood_bank_license_number" character varying, "p_storage_capacity" integer, "p_cold_storage_available" boolean, "p_blood_processing_available" boolean, "p_operating_hours" character varying) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."ai_chat_history" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "question" "text" NOT NULL,
    "response" "text" NOT NULL,
    "model_used" character varying(100) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."ai_chat_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."alembic_version" (
    "version_num" character varying(32) NOT NULL
);


ALTER TABLE "public"."alembic_version" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_logs" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid",
    "action" character varying(100) NOT NULL,
    "entity_type" character varying(100) NOT NULL,
    "entity_id" "uuid",
    "description" "text",
    "ip_address" character varying(50),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."blood_banks" (
    "organization_id" "uuid" NOT NULL,
    "license_number" character varying(100) NOT NULL,
    "storage_capacity" integer,
    "cold_storage_available" boolean NOT NULL,
    "blood_processing_available" boolean NOT NULL,
    "operating_hours" character varying(100),
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."blood_banks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."blood_groups" (
    "code" character varying(5) NOT NULL,
    "name" character varying(50) NOT NULL,
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."blood_groups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."blood_inventory" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "blood_group_id" "uuid" NOT NULL,
    "total_units" integer NOT NULL,
    "available_units" integer NOT NULL,
    "reserved_units" integer NOT NULL,
    "donation_date" timestamp with time zone NOT NULL,
    "expiry_date" timestamp with time zone NOT NULL,
    "storage_location" character varying(100),
    "status" character varying(20) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ck_blood_inventory_check_available_units_positive" CHECK (("available_units" >= 0)),
    CONSTRAINT "ck_blood_inventory_check_inventory_balance" CHECK ((("available_units" + "reserved_units") <= "total_units")),
    CONSTRAINT "ck_blood_inventory_check_reserved_units_positive" CHECK (("reserved_units" >= 0)),
    CONSTRAINT "ck_blood_inventory_check_total_units_positive" CHECK (("total_units" >= 0))
);


ALTER TABLE "public"."blood_inventory" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."blood_requests" (
    "id" "uuid" NOT NULL,
    "requester_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "blood_group_id" "uuid" NOT NULL,
    "units_required" integer NOT NULL,
    "urgency" character varying(20) NOT NULL,
    "status" character varying(20) NOT NULL,
    "required_date" timestamp with time zone NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "patient_id" "uuid" NOT NULL,
    "deleted_at" timestamp with time zone,
    CONSTRAINT "ck_blood_requests_check_units_required_positive" CHECK (("units_required" > 0))
);


ALTER TABLE "public"."blood_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."blood_reservations" (
    "id" "uuid" NOT NULL,
    "blood_request_id" "uuid" NOT NULL,
    "blood_inventory_id" "uuid" NOT NULL,
    "units_reserved" integer NOT NULL,
    "status" character varying(20) NOT NULL,
    "reserved_until" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ck_blood_reservations_check_reserved_units_positive" CHECK (("units_reserved" > 0))
);


ALTER TABLE "public"."blood_reservations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cities" (
    "province_id" "uuid" NOT NULL,
    "name" character varying(100) NOT NULL,
    "code" character varying(20) NOT NULL,
    "is_active" boolean NOT NULL,
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "latitude" numeric(9,6),
    "longitude" numeric(9,6)
);


ALTER TABLE "public"."cities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."donation_history" (
    "id" "uuid" NOT NULL,
    "donor_id" "uuid" NOT NULL,
    "organization_id" "uuid" NOT NULL,
    "blood_group_id" "uuid" NOT NULL,
    "units_donated" integer NOT NULL,
    "donation_date" timestamp with time zone NOT NULL,
    "verified" boolean NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ck_donation_history_check_units_donated_positive" CHECK (("units_donated" > 0))
);


ALTER TABLE "public"."donation_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."donor_availability" (
    "id" "uuid" NOT NULL,
    "donor_id" "uuid" NOT NULL,
    "is_available" boolean NOT NULL,
    "last_checked_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "next_eligible_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."donor_availability" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."donor_matches" (
    "id" "uuid" NOT NULL,
    "blood_request_id" "uuid" NOT NULL,
    "donor_id" "uuid" NOT NULL,
    "compatibility_score" double precision NOT NULL,
    "distance_km" double precision NOT NULL,
    "ai_reason" character varying(255),
    "status" character varying(20) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."donor_matches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."donor_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "date_of_birth" "date",
    "weight" numeric(5,2),
    "last_donation_date" "date",
    "availability_status" character varying(30) DEFAULT 'available'::character varying NOT NULL,
    "eligibility_status" character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."donor_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."donors" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "blood_group_id" "uuid" NOT NULL,
    "city_id" "uuid" NOT NULL,
    "phone_number" character varying(20) NOT NULL,
    "date_of_birth" timestamp with time zone NOT NULL,
    "gender" character varying(20) NOT NULL,
    "is_available" boolean NOT NULL,
    "total_donations" integer NOT NULL,
    "last_donation_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."donors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."emergency_sos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "blood_group_id" "uuid" NOT NULL,
    "city_id" "uuid",
    "units_required" integer NOT NULL,
    "urgency_level" character varying(20) NOT NULL,
    "description" "text",
    "status" character varying(20) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "gps_accuracy" double precision,
    "location_timestamp" timestamp with time zone
);


ALTER TABLE "public"."emergency_sos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."government_analytics" (
    "id" "uuid" NOT NULL,
    "metric_name" character varying(100) NOT NULL,
    "metric_value" integer NOT NULL,
    "region" character varying(100),
    "extra_data" json,
    "generated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."government_analytics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hospitals" (
    "organization_id" "uuid" NOT NULL,
    "hospital_type" character varying(50) NOT NULL,
    "license_number" character varying(100) NOT NULL,
    "emergency_service" boolean NOT NULL,
    "blood_storage_available" boolean NOT NULL,
    "total_beds" integer,
    "icu_available" boolean NOT NULL,
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."hospitals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" character varying(150) NOT NULL,
    "message" "text" NOT NULL,
    "notification_type" character varying(50) NOT NULL,
    "is_read" boolean NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organization_staff" (
    "organization_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "is_primary" boolean NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."organization_staff" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "city_id" "uuid" NOT NULL,
    "organization_type" "public"."organization_type" NOT NULL,
    "name" character varying(200) NOT NULL,
    "registration_number" character varying(100),
    "phone" character varying(30) NOT NULL,
    "email" character varying(150),
    "address" character varying(500) NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "verification_status" "public"."verification_status" NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "verified_at" timestamp with time zone,
    "verified_by" "uuid",
    "verification_notes" "text"
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patients" (
    "user_id" "uuid" NOT NULL,
    "blood_group_id" "uuid",
    "date_of_birth" "date",
    "gender" character varying(20),
    "emergency_contact" character varying(20),
    "medical_notes" character varying(500),
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."patients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "full_name" "text" NOT NULL,
    "gender" "text",
    "date_of_birth" "date",
    "blood_group" "text",
    "province" "text",
    "city" "text",
    "address" "text",
    "emergency_name" "text",
    "emergency_phone" "text",
    "weight" numeric,
    "is_donor" boolean DEFAULT true NOT NULL,
    "profile_image" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."provinces" (
    "name" character varying(100) NOT NULL,
    "code" character varying(10) NOT NULL,
    "is_active" boolean NOT NULL,
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."provinces" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."refresh_tokens" (
    "user_id" "uuid" NOT NULL,
    "token_hash" "text" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "revoked_at" timestamp with time zone,
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."refresh_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" "uuid" NOT NULL,
    "name" character varying(50) NOT NULL,
    "description" character varying(255),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "role_id" "uuid" NOT NULL,
    "email" character varying(255) NOT NULL,
    "full_name" character varying(150) NOT NULL,
    "phone_number" character varying(20),
    "is_active" boolean NOT NULL,
    "is_verified" boolean NOT NULL,
    "last_login_at" timestamp with time zone,
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."alembic_version"
    ADD CONSTRAINT "alembic_version_pkc" PRIMARY KEY ("version_num");



ALTER TABLE ONLY "public"."donor_profiles"
    ADD CONSTRAINT "donor_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."donor_profiles"
    ADD CONSTRAINT "donor_profiles_user_unique" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."ai_chat_history"
    ADD CONSTRAINT "pk_ai_chat_history" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "pk_audit_logs" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."blood_banks"
    ADD CONSTRAINT "pk_blood_banks" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."blood_groups"
    ADD CONSTRAINT "pk_blood_groups" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."blood_inventory"
    ADD CONSTRAINT "pk_blood_inventory" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."blood_requests"
    ADD CONSTRAINT "pk_blood_requests" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."blood_reservations"
    ADD CONSTRAINT "pk_blood_reservations" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cities"
    ADD CONSTRAINT "pk_cities" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."donation_history"
    ADD CONSTRAINT "pk_donation_history" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."donor_availability"
    ADD CONSTRAINT "pk_donor_availability" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."donor_matches"
    ADD CONSTRAINT "pk_donor_matches" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."donors"
    ADD CONSTRAINT "pk_donors" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."emergency_sos"
    ADD CONSTRAINT "pk_emergency_sos" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."government_analytics"
    ADD CONSTRAINT "pk_government_analytics" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."hospitals"
    ADD CONSTRAINT "pk_hospitals" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "pk_notifications" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organization_staff"
    ADD CONSTRAINT "pk_organization_staff" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "pk_organizations" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "pk_patients" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."provinces"
    ADD CONSTRAINT "pk_provinces" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."refresh_tokens"
    ADD CONSTRAINT "pk_refresh_tokens" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "pk_roles" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "pk_users" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."blood_banks"
    ADD CONSTRAINT "uq_blood_banks_license_number" UNIQUE ("license_number");



ALTER TABLE ONLY "public"."blood_banks"
    ADD CONSTRAINT "uq_blood_banks_organization_id" UNIQUE ("organization_id");



ALTER TABLE ONLY "public"."blood_groups"
    ADD CONSTRAINT "uq_blood_groups_code" UNIQUE ("code");



ALTER TABLE ONLY "public"."blood_groups"
    ADD CONSTRAINT "uq_blood_groups_name" UNIQUE ("name");



ALTER TABLE ONLY "public"."cities"
    ADD CONSTRAINT "uq_cities_code" UNIQUE ("code");



ALTER TABLE ONLY "public"."cities"
    ADD CONSTRAINT "uq_city_province_name" UNIQUE ("province_id", "name");



ALTER TABLE ONLY "public"."donor_availability"
    ADD CONSTRAINT "uq_donor_availability_donor_id" UNIQUE ("donor_id");



ALTER TABLE ONLY "public"."donors"
    ADD CONSTRAINT "uq_donors_user_id" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."hospitals"
    ADD CONSTRAINT "uq_hospitals_license_number" UNIQUE ("license_number");



ALTER TABLE ONLY "public"."hospitals"
    ADD CONSTRAINT "uq_hospitals_organization_id" UNIQUE ("organization_id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "uq_organizations_registration_number" UNIQUE ("registration_number");



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "uq_patients_user_id" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."provinces"
    ADD CONSTRAINT "uq_provinces_code" UNIQUE ("code");



ALTER TABLE ONLY "public"."provinces"
    ADD CONSTRAINT "uq_provinces_name" UNIQUE ("name");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "uq_roles_name" UNIQUE ("name");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "uq_users_email" UNIQUE ("email");



CREATE INDEX "ix_ai_chat_history_user_date" ON "public"."ai_chat_history" USING "btree" ("user_id", "created_at");



CREATE INDEX "ix_audit_logs_entity" ON "public"."audit_logs" USING "btree" ("entity_type", "entity_id");



CREATE INDEX "ix_audit_logs_user_action" ON "public"."audit_logs" USING "btree" ("user_id", "action");



CREATE INDEX "ix_blood_banks_license_number" ON "public"."blood_banks" USING "btree" ("license_number");



CREATE INDEX "ix_blood_inventory_org_group" ON "public"."blood_inventory" USING "btree" ("organization_id", "blood_group_id");



CREATE INDEX "ix_blood_requests_search" ON "public"."blood_requests" USING "btree" ("blood_group_id", "organization_id", "status");



CREATE INDEX "ix_blood_reservations_request_status" ON "public"."blood_reservations" USING "btree" ("blood_request_id", "status");



CREATE INDEX "ix_cities_province_id" ON "public"."cities" USING "btree" ("province_id");



CREATE INDEX "ix_cities_province_name" ON "public"."cities" USING "btree" ("province_id", "name");



CREATE INDEX "ix_donation_history_donor_date" ON "public"."donation_history" USING "btree" ("donor_id", "donation_date");



CREATE INDEX "ix_donor_availability_search" ON "public"."donor_availability" USING "btree" ("is_available", "next_eligible_date");



CREATE INDEX "ix_donor_matches_request_score" ON "public"."donor_matches" USING "btree" ("blood_request_id", "compatibility_score");



CREATE INDEX "ix_donors_matching_search" ON "public"."donors" USING "btree" ("blood_group_id", "city_id", "is_available");



CREATE INDEX "ix_emergency_sos_search" ON "public"."emergency_sos" USING "btree" ("blood_group_id", "city_id", "status");



CREATE INDEX "ix_government_analytics_metric_region" ON "public"."government_analytics" USING "btree" ("metric_name", "region");



CREATE INDEX "ix_hospitals_license_number" ON "public"."hospitals" USING "btree" ("license_number");



CREATE INDEX "ix_notifications_user_read" ON "public"."notifications" USING "btree" ("user_id", "is_read");



CREATE INDEX "ix_organizations_name" ON "public"."organizations" USING "btree" ("name");



CREATE INDEX "ix_provinces_name" ON "public"."provinces" USING "btree" ("name");



CREATE INDEX "ix_users_email" ON "public"."users" USING "btree" ("email");



CREATE UNIQUE INDEX "uq_organization_staff_active_user" ON "public"."organization_staff" USING "btree" ("user_id") WHERE ("deleted_at" IS NULL);



ALTER TABLE ONLY "public"."donor_profiles"
    ADD CONSTRAINT "donor_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ai_chat_history"
    ADD CONSTRAINT "fk_ai_chat_history_user_id_users" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."audit_logs"
    ADD CONSTRAINT "fk_audit_logs_user_id_users" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."blood_banks"
    ADD CONSTRAINT "fk_blood_banks_organization_id_organizations" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."blood_inventory"
    ADD CONSTRAINT "fk_blood_inventory_blood_group_id_blood_groups" FOREIGN KEY ("blood_group_id") REFERENCES "public"."blood_groups"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."blood_inventory"
    ADD CONSTRAINT "fk_blood_inventory_organization_id_organizations" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."blood_requests"
    ADD CONSTRAINT "fk_blood_requests_blood_group_id_blood_groups" FOREIGN KEY ("blood_group_id") REFERENCES "public"."blood_groups"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."blood_requests"
    ADD CONSTRAINT "fk_blood_requests_organization_id_organizations" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."blood_requests"
    ADD CONSTRAINT "fk_blood_requests_patient_id_patients" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."blood_requests"
    ADD CONSTRAINT "fk_blood_requests_requester_id_users" FOREIGN KEY ("requester_id") REFERENCES "public"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."blood_reservations"
    ADD CONSTRAINT "fk_blood_reservations_blood_inventory_id_blood_inventory" FOREIGN KEY ("blood_inventory_id") REFERENCES "public"."blood_inventory"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."blood_reservations"
    ADD CONSTRAINT "fk_blood_reservations_blood_request_id_blood_requests" FOREIGN KEY ("blood_request_id") REFERENCES "public"."blood_requests"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."cities"
    ADD CONSTRAINT "fk_cities_province_id_provinces" FOREIGN KEY ("province_id") REFERENCES "public"."provinces"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."donation_history"
    ADD CONSTRAINT "fk_donation_history_blood_group_id_blood_groups" FOREIGN KEY ("blood_group_id") REFERENCES "public"."blood_groups"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."donation_history"
    ADD CONSTRAINT "fk_donation_history_donor_id_donors" FOREIGN KEY ("donor_id") REFERENCES "public"."donors"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."donation_history"
    ADD CONSTRAINT "fk_donation_history_organization_id_organizations" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."donor_availability"
    ADD CONSTRAINT "fk_donor_availability_donor_id_donors" FOREIGN KEY ("donor_id") REFERENCES "public"."donors"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."donor_matches"
    ADD CONSTRAINT "fk_donor_matches_blood_request_id_blood_requests" FOREIGN KEY ("blood_request_id") REFERENCES "public"."blood_requests"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."donor_matches"
    ADD CONSTRAINT "fk_donor_matches_donor_id_donors" FOREIGN KEY ("donor_id") REFERENCES "public"."donors"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."donors"
    ADD CONSTRAINT "fk_donors_blood_group_id_blood_groups" FOREIGN KEY ("blood_group_id") REFERENCES "public"."blood_groups"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."donors"
    ADD CONSTRAINT "fk_donors_city_id_cities" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."donors"
    ADD CONSTRAINT "fk_donors_user_id_users" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."emergency_sos"
    ADD CONSTRAINT "fk_emergency_sos_blood_group_id_blood_groups" FOREIGN KEY ("blood_group_id") REFERENCES "public"."blood_groups"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."emergency_sos"
    ADD CONSTRAINT "fk_emergency_sos_city_id_cities" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."emergency_sos"
    ADD CONSTRAINT "fk_emergency_sos_user_id_users" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."hospitals"
    ADD CONSTRAINT "fk_hospitals_organization_id_organizations" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "fk_notifications_user_id_users" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organization_staff"
    ADD CONSTRAINT "fk_organization_staff_organization_id_organizations" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organization_staff"
    ADD CONSTRAINT "fk_organization_staff_user_id_users" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "fk_organizations_city_id_cities" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "fk_patients_blood_group_id_blood_groups" FOREIGN KEY ("blood_group_id") REFERENCES "public"."blood_groups"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "fk_patients_user_id_users" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."refresh_tokens"
    ADD CONSTRAINT "fk_refresh_tokens_user_id_users" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "fk_users_auth_user" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "fk_users_role_id_roles" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



CREATE POLICY "Anyone can read active cities" ON "public"."cities" FOR SELECT TO "authenticated", "anon" USING ((("is_active" = true) AND ("deleted_at" IS NULL)));



CREATE POLICY "Anyone can read active provinces" ON "public"."provinces" FOR SELECT TO "authenticated", "anon" USING ((("is_active" = true) AND ("deleted_at" IS NULL)));



CREATE POLICY "Authenticated users can read blood groups" ON "public"."blood_groups" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can view donors" ON "public"."donors" FOR SELECT TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_government_admin"() OR ("user_id" = "auth"."uid"()) OR ("is_available" = true)));



CREATE POLICY "Authenticated users can view roles" ON "public"."roles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can view verified organizations" ON "public"."organizations" FOR SELECT TO "authenticated" USING ((("verification_status" = 'VERIFIED'::"public"."verification_status") AND ("deleted_at" IS NULL)));



CREATE POLICY "Government users can view analytics" ON "public"."government_analytics" FOR SELECT TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_government_admin"()));



CREATE POLICY "Healthcare roles can view SOS" ON "public"."emergency_sos" FOR SELECT TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_government_admin"() OR (EXISTS ( SELECT 1
   FROM "public"."organization_staff" "os"
  WHERE (("os"."user_id" = "auth"."uid"()) AND ("os"."deleted_at" IS NULL))))));



CREATE POLICY "Organization admins can delete inventory" ON "public"."blood_inventory" FOR DELETE TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_organization_admin"("organization_id")));



CREATE POLICY "Organization admins can insert inventory" ON "public"."blood_inventory" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_super_admin"() OR "public"."is_organization_admin"("organization_id")));



CREATE POLICY "Organization admins can update inventory" ON "public"."blood_inventory" FOR UPDATE TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_organization_admin"("organization_id"))) WITH CHECK (("public"."is_super_admin"() OR "public"."is_organization_admin"("organization_id")));



CREATE POLICY "Organization members can view inventory" ON "public"."blood_inventory" FOR SELECT TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_government_admin"() OR "public"."is_organization_member"("organization_id")));



CREATE POLICY "Organization members can view their organization" ON "public"."organizations" FOR SELECT TO "authenticated" USING ((("deleted_at" IS NULL) AND (EXISTS ( SELECT 1
   FROM "public"."organization_staff" "os"
  WHERE (("os"."organization_id" = "organizations"."id") AND ("os"."user_id" = "auth"."uid"()) AND ("os"."deleted_at" IS NULL))))));



CREATE POLICY "Privileged users can view audit logs" ON "public"."audit_logs" FOR SELECT TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_government_admin"()));



CREATE POLICY "Relevant users can view donor matches" ON "public"."donor_matches" FOR SELECT TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_government_admin"() OR (EXISTS ( SELECT 1
   FROM "public"."donors" "d"
  WHERE (("d"."id" = "donor_matches"."donor_id") AND ("d"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."blood_requests" "br"
  WHERE (("br"."id" = "donor_matches"."blood_request_id") AND (("br"."requester_id" = "auth"."uid"()) OR "public"."is_organization_member"("br"."organization_id")))))));



CREATE POLICY "Relevant users can view reservations" ON "public"."blood_reservations" FOR SELECT TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_government_admin"() OR (EXISTS ( SELECT 1
   FROM "public"."blood_requests" "br"
  WHERE (("br"."id" = "blood_reservations"."blood_request_id") AND (("br"."requester_id" = "auth"."uid"()) OR "public"."is_organization_member"("br"."organization_id")))))));



CREATE POLICY "Request owners can update requests" ON "public"."blood_requests" FOR UPDATE TO "authenticated" USING ((("requester_id" = "auth"."uid"()) OR "public"."is_super_admin"() OR "public"."is_government_admin"() OR "public"."is_organization_member"("organization_id"))) WITH CHECK ((("requester_id" = "auth"."uid"()) OR "public"."is_super_admin"() OR "public"."is_government_admin"() OR "public"."is_organization_member"("organization_id")));



CREATE POLICY "Users can Update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can create blood requests" ON "public"."blood_requests" FOR INSERT TO "authenticated" WITH CHECK (("requester_id" = "auth"."uid"()));



CREATE POLICY "Users can create own AI history" ON "public"."ai_chat_history" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));


CREATE POLICY "Users can create own SOS" ON "public"."emergency_sos" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));


CREATE POLICY "Users can create own organization membership" ON "public"."organization_staff" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));


CREATE POLICY "Users can create own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));


CREATE POLICY "Users can delete own organization membership" ON "public"."organization_staff" FOR DELETE TO "authenticated" USING (false);


CREATE POLICY "Users can delete their own notifications" ON "public"."notifications" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));


CREATE POLICY "Users can insert own donor profile" ON "public"."donors" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));


CREATE POLICY "Users can manage own availability" ON "public"."donor_availability" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."donors" "d"
  WHERE (("d"."id" = "donor_availability"."donor_id") AND ("d"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."donors" "d"
  WHERE (("d"."id" = "donor_availability"."donor_id") AND ("d"."user_id" = "auth"."uid"())))));


CREATE POLICY "Users can update own SOS" ON "public"."emergency_sos" FOR UPDATE TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR "public"."is_super_admin"() OR "public"."is_government_admin"())) WITH CHECK ((("user_id" = "auth"."uid"()) OR "public"."is_super_admin"() OR "public"."is_government_admin"()));


CREATE POLICY "Users can update own donor profile" ON "public"."donors" FOR UPDATE TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR "public"."is_super_admin"())) WITH CHECK ((("user_id" = "auth"."uid"()) OR "public"."is_super_admin"()));


CREATE POLICY "Users can update own organization membership" ON "public"."organization_staff" FOR UPDATE TO "authenticated" USING (false) WITH CHECK (false);


CREATE POLICY "Users can update their own notifications" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));


CREATE POLICY "Users can view donor availability" ON "public"."donor_availability" FOR SELECT TO "authenticated" USING (("public"."is_super_admin"() OR "public"."is_government_admin"() OR (EXISTS ( SELECT 1
   FROM "public"."donors" "d"
  WHERE (("d"."id" = "donor_availability"."donor_id") AND (("d"."user_id" = "auth"."uid"()) OR ("d"."is_available" = true)))))));


CREATE POLICY "Users can view own AI history" ON "public"."ai_chat_history" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));


CREATE POLICY "Users can view own SOS" ON "public"."emergency_sos" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));


CREATE POLICY "Users can view own application account" ON "public"."users" FOR SELECT TO "authenticated" USING ((("id" = "auth"."uid"()) AND ("deleted_at" IS NULL)));


CREATE POLICY "Users can view own organization membership" ON "public"."organization_staff" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) AND ("deleted_at" IS NULL)));


CREATE POLICY "Users can view own profile" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "user_id"));


CREATE POLICY "Users can view relevant blood requests" ON "public"."blood_requests" FOR SELECT TO "authenticated" USING ((("requester_id" = "auth"."uid"()) OR ("patient_id" IN ( SELECT "p"."id"
   FROM "public"."patients" "p"
  WHERE ("p"."user_id" = "auth"."uid"()))) OR "public"."is_super_admin"() OR "public"."is_government_admin"() OR "public"."is_organization_member"("organization_id")));


CREATE POLICY "Users can view their own notifications" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));


ALTER TABLE "public"."ai_chat_history" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."audit_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."blood_groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."blood_inventory" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."blood_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."blood_reservations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."donor_availability" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."donor_matches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."donor_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."donors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."emergency_sos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."government_analytics" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organization_staff" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user can delete profile " ON "public"."profiles" FOR DELETE USING (("auth"."uid"() = "user_id"));


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";


GRANT ALL ON FUNCTION "public"."current_user_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_role"() TO "service_role";


GRANT ALL ON FUNCTION "public"."handle_auth_user_verified"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_auth_user_verified"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_auth_user_verified"() TO "service_role";


GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";


GRANT ALL ON FUNCTION "public"."is_government_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_government_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_government_admin"() TO "service_role";


GRANT ALL ON FUNCTION "public"."is_organization_admin"("p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_organization_admin"("p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_organization_admin"("p_organization_id" "uuid") TO "service_role";


GRANT ALL ON FUNCTION "public"."is_organization_member"("p_organization_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_organization_member"("p_organization_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_organization_member"("p_organization_id" "uuid") TO "service_role";


GRANT ALL ON FUNCTION "public"."is_super_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_super_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_super_admin"() TO "service_role";


GRANT ALL ON FUNCTION "public"."register_organization"("p_user_id" "uuid", "p_city_id" "uuid", "p_organization_type" "public"."organization_type", "p_organization_name" character varying, "p_registration_number" character varying, "p_phone" character varying, "p_email" character varying, "p_address" character varying, "p_latitude" double precision, "p_longitude" double precision, "p_hospital_type" character varying, "p_hospital_license_number" character varying, "p_emergency_service" boolean, "p_blood_storage_available" boolean, "p_total_beds" integer, "p_icu_available" boolean, "p_blood_bank_license_number" character varying, "p_storage_capacity" integer, "p_cold_storage_available" boolean, "p_blood_processing_available" boolean, "p_operating_hours" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."register_organization"("p_user_id" "uuid", "p_city_id" "uuid", "p_organization_type" "public"."organization_type", "p_organization_name" character varying, "p_registration_number" character varying, "p_phone" character varying, "p_email" character varying, "p_address" character varying, "p_latitude" double precision, "p_longitude" double precision, "p_hospital_type" character varying, "p_hospital_license_number" character varying, "p_emergency_service" boolean, "p_blood_storage_available" boolean, "p_total_beds" integer, "p_icu_available" boolean, "p_blood_bank_license_number" character varying, "p_storage_capacity" integer, "p_cold_storage_available" boolean, "p_blood_processing_available" boolean, "p_operating_hours" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_organization"("p_user_id" "uuid", "p_city_id" "uuid", "p_organization_type" "public"."organization_type", "p_organization_name" character varying, "p_registration_number" character varying, "p_phone" character varying, "p_email" character varying, "p_address" character varying, "p_latitude" double precision, "p_longitude" double precision, "p_hospital_type" character varying, "p_hospital_license_number" character varying, "p_emergency_service" boolean, "p_blood_storage_available" boolean, "p_total_beds" integer, "p_icu_available" boolean, "p_blood_bank_license_number" character varying, "p_storage_capacity" integer, "p_cold_storage_available" boolean, "p_blood_processing_available" boolean, "p_operating_hours" character varying) TO "service_role";


GRANT ALL ON TABLE "public"."ai_chat_history" TO "anon";
GRANT ALL ON TABLE "public"."ai_chat_history" TO "authenticated";
GRANT ALL ON TABLE "public"."ai_chat_history" TO "service_role";


GRANT ALL ON TABLE "public"."alembic_version" TO "anon";
GRANT ALL ON TABLE "public"."alembic_version" TO "authenticated";
GRANT ALL ON TABLE "public"."alembic_version" TO "service_role";


GRANT ALL ON TABLE "public"."audit_logs" TO "anon";
GRANT ALL ON TABLE "public"."audit_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_logs" TO "service_role";


GRANT ALL ON TABLE "public"."blood_banks" TO "anon";
GRANT ALL ON TABLE "public"."blood_banks" TO "authenticated";
GRANT ALL ON TABLE "public"."blood_banks" TO "service_role";


GRANT ALL ON TABLE "public"."blood_groups" TO "anon";
GRANT ALL ON TABLE "public"."blood_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."blood_groups" TO "service_role";


GRANT ALL ON TABLE "public"."blood_inventory" TO "anon";
GRANT ALL ON TABLE "public"."blood_inventory" TO "authenticated";
GRANT ALL ON TABLE "public"."blood_inventory" TO "service_role";


GRANT ALL ON TABLE "public"."blood_requests" TO "anon";
GRANT ALL ON TABLE "public"."blood_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."blood_requests" TO "service_role";


GRANT ALL ON TABLE "public"."blood_reservations" TO "anon";
GRANT ALL ON TABLE "public"."blood_reservations" TO "authenticated";
GRANT ALL ON TABLE "public"."blood_reservations" TO "service_role";


GRANT ALL ON TABLE "public"."cities" TO "anon";
GRANT ALL ON TABLE "public"."cities" TO "authenticated";
GRANT ALL ON TABLE "public"."cities" TO "service_role";


GRANT ALL ON TABLE "public"."donation_history" TO "anon";
GRANT ALL ON TABLE "public"."donation_history" TO "authenticated";
GRANT ALL ON TABLE "public"."donation_history" TO "service_role";


GRANT ALL ON TABLE "public"."donor_availability" TO "anon";
GRANT ALL ON TABLE "public"."donor_availability" TO "authenticated";
GRANT ALL ON TABLE "public"."donor_availability" TO "service_role";


GRANT ALL ON TABLE "public"."donor_matches" TO "anon";
GRANT ALL ON TABLE "public"."donor_matches" TO "authenticated";
GRANT ALL ON TABLE "public"."donor_matches" TO "service_role";


GRANT ALL ON TABLE "public"."donor_profiles" TO "anon";
GRANT ALL ON TABLE "public"."donor_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."donor_profiles" TO "service_role";


GRANT ALL ON TABLE "public"."donors" TO "anon";
GRANT ALL ON TABLE "public"."donors" TO "authenticated";
GRANT ALL ON TABLE "public"."donors" TO "service_role";


GRANT ALL ON TABLE "public"."emergency_sos" TO "anon";
GRANT ALL ON TABLE "public"."emergency_sos" TO "authenticated";
GRANT ALL ON TABLE "public"."emergency_sos" TO "service_role";


GRANT ALL ON TABLE "public"."government_analytics" TO "anon";
GRANT ALL ON TABLE "public"."government_analytics" TO "authenticated";
GRANT ALL ON TABLE "public"."government_analytics" TO "service_role";


GRANT ALL ON TABLE "public"."hospitals" TO "anon";
GRANT ALL ON TABLE "public"."hospitals" TO "authenticated";
GRANT ALL ON TABLE "public"."hospitals" TO "service_role";


GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";


GRANT ALL ON TABLE "public"."organization_staff" TO "anon";
GRANT ALL ON TABLE "public"."organization_staff" TO "authenticated";
GRANT ALL ON TABLE "public"."organization_staff" TO "service_role";


GRANT ALL ON TABLE "public"."organizations" TO "anon";
GRANT ALL ON TABLE "public"."organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."organizations" TO "service_role";


GRANT ALL ON TABLE "public"."patients" TO "anon";
GRANT ALL ON TABLE "public"."patients" TO "authenticated";
GRANT ALL ON TABLE "public"."patients" TO "service_role";


GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";


GRANT ALL ON TABLE "public"."provinces" TO "anon";
GRANT ALL ON TABLE "public"."provinces" TO "authenticated";
GRANT ALL ON TABLE "public"."provinces" TO "service_role";


GRANT ALL ON TABLE "public"."refresh_tokens" TO "anon";
GRANT ALL ON TABLE "public"."refresh_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."refresh_tokens" TO "service_role";


GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";


GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";


ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
