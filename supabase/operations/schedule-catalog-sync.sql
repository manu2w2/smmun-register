-- Requiere secretos en Vault: catalog_sync_url y catalog_sync_secret.
-- Ejecutar únicamente en el entorno de staging identificado, tras revisar el plan.
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
