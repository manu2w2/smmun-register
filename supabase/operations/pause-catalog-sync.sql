begin;
select cron.alter_job(jobid, active := false) from cron.job where jobname = 'catalog-sync';
update catalog.sync_schedule set active = false, changed_at = now()
where job_name = 'catalog-sync' and active;
commit;
