create schema catalog;
revoke all on schema catalog from public, anon, authenticated, service_role;

create table catalog.representations (
    id uuid primary key default gen_random_uuid(),
    edition text not null check (edition ~ '^[a-z0-9][a-z0-9-]{0,63}$'),
    committee text not null check (committee ~ '\S'),
    representation_name text not null check (representation_name ~ '\S'),
    representation_type text not null check (representation_type ~ '\S'),
    allows_co_delegation boolean not null,
    disponible boolean not null default true
);

create unique index representations_edition_committee_name_key
    on catalog.representations (edition, lower(committee), lower(representation_name));

alter table catalog.representations enable row level security;
revoke all on catalog.representations from public, anon, authenticated, service_role;

-- Recibe un lote normalizado desde el CSV o, más adelante, desde Sheets.
create function catalog.import_representations(
    target_edition text, source_rows jsonb, apply_changes boolean, allow_missing boolean
) returns jsonb
language plpgsql volatile security invoker set search_path = ''
as $$
declare
    invalid_positions bigint[];
    duplicate_lines integer[];
    written_count bigint := 0;
    report jsonb;
begin
    if target_edition is null or target_edition !~ '^[a-z0-9][a-z0-9-]{0,63}$' then
        raise exception 'Identificador de edición inválido';
    end if;
    if source_rows is null or jsonb_typeof(source_rows) <> 'array' then
        raise exception 'Se requiere un lote de filas';
    end if;
    if jsonb_array_length(source_rows) = 0 then
        raise exception 'El lote no contiene representaciones';
    end if;

    select array_agg(position) into invalid_positions
    from jsonb_array_elements(source_rows) with ordinality as items(entry, position)
    where jsonb_typeof(entry->'committee') is distinct from 'string' or entry->>'committee' !~ '\S'
       or jsonb_typeof(entry->'representation_name') is distinct from 'string' or entry->>'representation_name' !~ '\S'
       or jsonb_typeof(entry->'representation_type') is distinct from 'string' or entry->>'representation_type' !~ '\S'
       or jsonb_typeof(entry->'allows_co_delegation') is distinct from 'boolean'
       or jsonb_typeof(entry->'source_line') is distinct from 'number' or entry->>'source_line' !~ '^[1-9][0-9]*$';
    if invalid_positions is not null then
        raise exception 'Filas inválidas en las posiciones del lote %', invalid_positions;
    end if;

    select array_agg(row_number order by row_number) into duplicate_lines
    from (
        select unnest(array_agg(source_line)) as row_number
        from jsonb_to_recordset(source_rows) as parsed(committee text, representation_name text, source_line integer)
        group by lower(committee), lower(representation_name)
        having count(*) > 1
    ) as duplicates;
    if duplicate_lines is not null then
        raise exception 'Representaciones duplicadas en las líneas %', duplicate_lines;
    end if;

    if apply_changes then
        -- Serializa las importaciones de la misma edición antes de releer el catálogo.
        perform pg_advisory_xact_lock(hashtextextended('catalog.representations:' || target_edition, 0));
    end if;

    with incoming as (
        select * from jsonb_to_recordset(source_rows) as parsed(
            committee text, representation_name text, representation_type text,
            allows_co_delegation boolean, source_line integer
        )
    ), current_rows as (
        select * from catalog.representations where edition = target_edition
    ), differences as (
        select case
            when current_rows.id is null then 'alta'
            when incoming.source_line is null then 'ausente'
            when (incoming.committee, incoming.representation_name, incoming.representation_type,
                  incoming.allows_co_delegation) is distinct from
                 (current_rows.committee, current_rows.representation_name, current_rows.representation_type,
                  current_rows.allows_co_delegation) then 'cambio'
            else 'igual' end as action,
            current_rows.id,
            incoming.source_line,
            coalesce(incoming.committee, current_rows.committee) as committee,
            coalesce(incoming.representation_name, current_rows.representation_name) as representation_name,
            incoming.representation_type,
            incoming.allows_co_delegation
        from incoming full join current_rows
          on lower(incoming.committee) = lower(current_rows.committee)
         and lower(incoming.representation_name) = lower(current_rows.representation_name)
    ), summary as (
        select count(*) filter (where action = 'alta') as altas,
               count(*) filter (where action = 'cambio') as cambios,
               count(*) filter (where action = 'igual') as iguales,
               count(*) filter (where action = 'ausente') as ausentes,
               coalesce(jsonb_agg(jsonb_strip_nulls(to_jsonb(differences))
                   order by action, committee, representation_name) filter (where action <> 'igual'), '[]') as rows
        from differences
    )
    select to_jsonb(summary) || jsonb_build_object(
        'revisar_renombres', ausentes > 0 and altas > 0
    ) into report from summary;

    if apply_changes then
        if allow_missing is not true and (report->>'ausentes')::bigint > 0 then
            raise exception 'Hay % representaciones ausentes. Revisa el lote antes de aplicar', report->>'ausentes';
        end if;

        insert into catalog.representations (
            edition, committee, representation_name, representation_type, allows_co_delegation
        )
        select target_edition, committee, representation_name, representation_type, allows_co_delegation
        from jsonb_to_recordset(report->'rows') as changes(
            action text, committee text, representation_name text, representation_type text, allows_co_delegation boolean
        )
        where action in ('alta', 'cambio')
        order by lower(committee), lower(representation_name)
        on conflict (edition, lower(committee), lower(representation_name)) do update set
            committee = excluded.committee,
            representation_name = excluded.representation_name,
            representation_type = excluded.representation_type,
            allows_co_delegation = excluded.allows_co_delegation;
        get diagnostics written_count = row_count;
    end if;
    return report || jsonb_build_object('aplicado', apply_changes is true, 'escritas', written_count);
end;
$$;

revoke all on function catalog.import_representations(text, jsonb, boolean, boolean)
    from public, anon, authenticated, service_role;
