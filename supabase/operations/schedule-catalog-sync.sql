-- Requiere secretos en Vault: catalog_sync_url y catalog_sync_secret.
-- Ejecutar únicamente en el entorno de staging identificado, tras revisar el plan.
-- En la misma sesión: SET catalog.schedule_edition = 'edicion-de-staging';
begin;
do $check$
begin
  if not exists (select from catalog.sync_runs where edition = current_setting('catalog.schedule_edition')
      and mode = 'apply' and status = 'success') then
    raise exception 'Se necesita una aplicación manual correcta para esta edición';
  end if;
  if not exists (select from vault.decrypted_secrets where name = 'catalog_sync_url'
      and decrypted_secret = 'https://thospiqlsgtsxzkbpkux.supabase.co/functions/v1/catalog-sync')
     or not exists (select from vault.decrypted_secrets where name = 'catalog_sync_secret' and length(decrypted_secret) > 0) then
    raise exception 'Revisa la URL de staging y el secreto de invocación en Vault';
  end if;
end;
$check$;
select cron.schedule(
  'catalog-sync',
  '*/20 * * * *',
  $job$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'catalog_sync_url'),
      headers := jsonb_build_object(
        'content-type', 'application/json',
        'x-catalog-sync-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'catalog_sync_secret')
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 120000
    );
  $job$
);
select cron.alter_job(jobid, active := true) from cron.job where jobname = 'catalog-sync';
insert into catalog.sync_schedule (job_name, edition, active)
values ('catalog-sync', current_setting('catalog.schedule_edition'), true)
on conflict (job_name) do update set edition = excluded.edition, active = true, changed_at = now()
where (sync_schedule.edition, sync_schedule.active) is distinct from (excluded.edition, true);
commit;
