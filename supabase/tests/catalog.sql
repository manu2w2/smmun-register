do $$
declare
    edition_slug text := 'verify-' || left(gen_random_uuid()::text, 8);
    source jsonb := '[
        {"source_line":2,"committee":"Comité","representation_name":"Aurora","representation_type":"País","allows_co_delegation":true},
        {"source_line":3,"committee":"Otro comité","representation_name":"Aurora","representation_type":"País","allows_co_delegation":false}
    ]';
    report jsonb;
    original_id uuid;
begin
    report := catalog.import_representations(edition_slug, source, false, false);
    if report->>'altas' <> '2' or exists (select from catalog.representations where edition = edition_slug) then
        raise exception 'La vista previa debe mostrar dos altas sin escribir';
    end if;

    report := catalog.import_representations(edition_slug, source, true, false);
    if report->>'escritas' <> '2'
        or (select count(*) from catalog.representations where edition = edition_slug and disponible) <> 2 then
        raise exception 'Ambos comités deben tener una representación disponible';
    end if;
    update catalog.representations set disponible = false
    where edition = edition_slug and committee = 'Comité' returning id into strict original_id;

    source := jsonb_set(source, '{0,representation_name}', '"AURORA"');
    source := jsonb_set(source, '{0,representation_type}', '"Organización"');
    report := catalog.import_representations(edition_slug, source, true, false);
    if report->>'cambios' <> '1' or not exists (
        select from catalog.representations where id = original_id and not disponible
            and representation_type = 'Organización' and representation_name = 'AURORA'
    ) then
        raise exception 'El cambio de atributos debe mantener el UUID y la disponibilidad';
    end if;
    report := catalog.import_representations(edition_slug, source, true, false);
    if report->>'iguales' <> '2' or report->>'escritas' <> '0' then
        raise exception 'El lote idéntico debe dejar ambas filas intactas';
    end if;

    begin
        perform catalog.import_representations(edition_slug, source || (source->0), true, false);
        raise exception 'Se aceptó un duplicado';
    exception when raise_exception then
        if sqlerrm not like 'Representaciones duplicadas%' then raise; end if;
    end;

    source := jsonb_build_array(jsonb_set(source->0, '{representation_name}', '"Aurora nueva"'));
    report := catalog.import_representations(edition_slug, source, false, false);
    if report->>'revisar_renombres' <> 'true' or report->>'ausentes' <> '2' then
        raise exception 'La vista previa debe alertar sobre posibles renombres y ausencias';
    end if;
    begin
        perform catalog.import_representations(edition_slug, source, true, false);
        raise exception 'Se aplicó un lote con ausencias sin revisión';
    exception when raise_exception then
        if sqlerrm not like 'Hay % representaciones ausentes%' then raise; end if;
    end;
    if (select count(*) from catalog.representations where edition = edition_slug) <> 2 then
        raise exception 'El lote bloqueado modificó la tabla';
    end if;

    perform catalog.import_representations(edition_slug, source, true, true);
    if (select count(*) from catalog.representations where edition = edition_slug) <> 3
        or not exists (select from catalog.representations where id = original_id and not disponible) then
        raise exception 'Aceptar ausencias debe dejar intactas las filas omitidas';
    end if;
    if exists (
        select from unnest(array['anon', 'authenticated', 'service_role']) as roles(role_name)
        where has_schema_privilege(role_name, 'catalog', 'USAGE')
           or has_table_privilege(role_name, 'catalog.representations', 'SELECT, INSERT, UPDATE, DELETE')
           or has_function_privilege(role_name, 'catalog.import_representations(text,jsonb,boolean,boolean)', 'EXECUTE')
    ) then
        raise exception 'El catálogo y la función deben ser privados';
    end if;

    -- Las modificaciones sintéticas se revierten al cerrar esta subtransacción.
    raise sqlstate 'ZX001';
exception when sqlstate 'ZX001' then
    null;
end;
$$;
