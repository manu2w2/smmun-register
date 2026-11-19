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
rollback;
