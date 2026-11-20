begin;
set local role catalog_sync;

do $$
declare
    i integer;
    inserted_id uuid;
    report jsonb;
begin
    for i in 1..12 loop
        if not catalog.reserve_sheet_read('test-quota') then
            raise exception 'La reserva % debería aceptarse', i;
        end if;
    end loop;
    if catalog.reserve_sheet_read('test-quota') then
        raise exception 'La decimotercera reserva debería rechazarse';
    end if;
    if not catalog.reserve_sheet_read('another-project') then
        raise exception 'Un proyecto distinto debe tener presupuesto independiente';
    end if;
    report := catalog.import_representations('test-sync-rls',
        '[{"source_line":2,"committee":"Prueba","representation_name":"Aurora","representation_type":"País","allows_co_delegation":true}]',
        true, false);
    if report->>'escritas' <> '1' then raise exception 'La importación falló'; end if;
    select id into inserted_id from catalog.representations where edition = 'test-sync-rls';
    begin
        update catalog.representations set disponible = false where id = inserted_id;
        raise exception 'El rol puede actualizar disponible';
    exception when insufficient_privilege then null;
    end;
    begin
        delete from catalog.representations where id = inserted_id;
        raise exception 'El rol puede borrar representaciones';
    exception when insufficient_privilege then null;
    end;
    insert into catalog.sync_runs (edition, mode, status) values ('test-sync-rls', 'preview', 'running')
        returning id into inserted_id;
    update catalog.sync_runs set status = 'success', finished_at = clock_timestamp(), altas = 1 where id = inserted_id;
end;
$$;

set local role catalog_viewer;
do $$
begin
    if not exists (select 1 from catalog.sync_runs where edition = 'test-sync-rls')
        or not exists (select 1 from catalog.representations where edition = 'test-sync-rls') then
        raise exception 'El panel debe poder leer ambas tablas';
    end if;
    begin
        insert into catalog.sync_runs (edition, mode, status) values ('test-sync-rls', 'preview', 'running');
        raise exception 'El rol de lectura puede escribir';
    exception when insufficient_privilege then null;
    end;
    begin
        perform catalog.reserve_sheet_read('test-quota');
        raise exception 'El rol de lectura puede reservar cuota';
    exception when insufficient_privilege then null;
    end;
end;
$$;

reset role;

-- El reloj de atraso comienza al activar. Las corridas omitidas no lo reinician.
insert into catalog.sync_schedule (job_name, edition, active, changed_at)
values ('catalog-sync', 'test-monitor', true, now() - interval '41 minutes')
on conflict (job_name) do update set edition = excluded.edition, active = true, changed_at = excluded.changed_at;
insert into catalog.sync_runs (edition, mode, status, started_at, finished_at)
values ('test-monitor', 'preview', 'skipped', now(), now());
set local role catalog_viewer;
do $$
begin
    if not ((catalog.panel_snapshot()->'schedules') @> '[{"edition":"test-monitor","active":true,"overdue":true}]') then
        raise exception 'Debe advertir después de dos intervalos sin una corrida completada';
    end if;
    if has_table_privilege(current_user, 'catalog.sync_schedule', 'UPDATE')
        or has_function_privilege('anon', 'catalog.panel_snapshot()', 'EXECUTE') then
        raise exception 'Los permisos del monitor deben ser de lectura interna';
    end if;
end;
$$;
reset role;
update catalog.sync_schedule set active = false where job_name = 'catalog-sync';
do $$
begin
    if not ((catalog.panel_snapshot()->'schedules') @> '[{"active":false,"overdue":false}]') then
        raise exception 'Una programación pausada no debe mostrar atraso';
    end if;
end;
$$;
update catalog.sync_schedule set active = true where job_name = 'catalog-sync';
insert into catalog.sync_runs (edition, mode, status, started_at, finished_at)
values ('test-monitor', 'preview', 'success', now() - interval '2 minutes', now() - interval '1 minute');
do $$
begin
    if not ((catalog.panel_snapshot()->'schedules') @> '[{"active":true,"overdue":false}]') then
        raise exception 'Una corrida completada debe actualizar el reloj de atraso';
    end if;
end;
$$;
rollback;
