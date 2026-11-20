<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { createClient, type SupabaseClient } from '@supabase/supabase-js';
  type Representation = {
    id: string; edition: string; committee: string; representation_name: string;
    representation_type: string; allows_co_delegation: boolean; disponible: boolean;
  };
  type Run = {
    id: string; edition: string; mode: string; status: string; started_at: string;
    finished_at: string | null; altas: number | null; cambios: number | null;
    iguales: number | null; ausentes: number | null; error_code: string | null;
  };
  type Schedule = { edition: string; active: boolean; overdue: boolean };
  type Catalog = { representations: Representation[]; runs: Run[]; schedules?: Schedule[] };
  let catalog = $state<Catalog | null>(null);
  let edition = $state('');
  let committee = $state('');
  let loading = $state(false);
  let error = $state('');
  let lastRead = $state<Date | null>(null);
  const panelMode = import.meta.env.VITE_CATALOG_PANEL_MODE || (import.meta.env.DEV ? 'hosted' : 'local');
  const hosted = panelMode === 'hosted';
  let client = $state.raw<SupabaseClient>();
  let baseUrl = '';
  let publishableKey = '';
  let signedIn = $state(false);
  let email = $state('');
  let password = $state('');
  let signingIn = $state(false);
  let signingOut = $state(false);
  let emailInput = $state<HTMLInputElement>();
  let refreshButton = $state<HTMLButtonElement>();
  let authError = $state('');
  let configurationError = $state('');
  let sessionGeneration = 0;
  let currentRequest: AbortController | undefined;
  let editions = $derived(catalog ? [...new Set(
    [...catalog.representations, ...catalog.runs, ...(catalog.schedules ?? [])].map(row => row.edition)
  )].sort() : []);
  let committees = $derived([...new Set((catalog?.representations ?? [])
    .filter((row) => !edition || row.edition === edition).map((row) => row.committee))].sort());
  let rows = $derived((catalog?.representations ?? []).filter((row) =>
    (!edition || row.edition === edition) && (!committee || row.committee === committee)));
  let summaries = $derived((edition ? [edition] : editions).map(value => {
    const runs = catalog?.runs.filter(run => run.edition === value) ?? [];
    const completed = runs.filter(run => ['success', 'review', 'error'].includes(run.status))
      .sort((a, b) => Date.parse(b.finished_at!) - Date.parse(a.finished_at!));
    return {
      edition: value, latest: runs[0], completed: completed[0],
      applied: completed.find(run => run.mode === 'apply' && run.status === 'success'),
      schedule: catalog?.schedules?.find(schedule => schedule.edition === value)
    };
  }));
  function date(value: string | Date | null | undefined) {
    return value ? new Intl.DateTimeFormat('es-MX', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) : 'Sin registro';
  }
  function label(run: Run) {
    if (run.status === 'running') return 'En curso';
    if (run.status === 'review') return 'Requiere revisión';
    if (run.status === 'error') return 'Falló';
    if (run.status === 'skipped') return 'Omitida';
    if (run.mode === 'preview') return 'Vista previa completada';
    return (run.altas ?? 0) + (run.cambios ?? 0) > 0 ? 'Actualización aplicada' : 'Sin cambios';
  }
  function clearCatalog() {
    catalog = null;
    lastRead = null;
    edition = '';
    committee = '';
  }
  async function signIn(event: SubmitEvent) {
    event.preventDefault();
    if (!client || signingIn || signingOut) return;
    signingIn = true;
    authError = '';
    try {
      const result = await client.auth.signInWithPassword({ email: email.trim(), password });
      password = '';
      if (result.error || !result.data.session) {
        authError = 'No se pudo iniciar sesión. Comprueba tus datos e inténtalo de nuevo.';
        return;
      }
      sessionGeneration++;
      signedIn = true;
      await refresh();
      await tick();
      if (signedIn) refreshButton?.focus();
    } catch {
      password = '';
      authError = 'No se pudo conectar con el servicio de acceso.';
    } finally {
      signingIn = false;
    }
  }
  function endSession(message: string) {
    sessionGeneration++;
    currentRequest?.abort();
    currentRequest = undefined;
    loading = false;
    signedIn = false;
    password = '';
    error = '';
    authError = message;
    clearCatalog();
  }
  async function signOut(message = '') {
    endSession(message);
    if (client) {
      signingOut = true;
      try { await client.auth.signOut({ scope: 'local' }); }
      catch { /* La vista ya no conserva datos ni tokens. */ }
      finally { signingOut = false; }
    }
    await tick();
    emailInput?.focus();
  }
  async function refresh() {
    if (loading || configurationError || (hosted && (!signedIn || !client))) return;
    loading = true;
    const generation = sessionGeneration;
    const controller = new AbortController();
    currentRequest = controller;
    try {
      let endpoint = '/api/catalog';
      let headers: Record<string, string> = {};
      if (hosted && client) {
        const { data, error: sessionError } = await client.auth.getSession();
        if (sessionError || !data.session) {
          await signOut('La sesión terminó. Inicia sesión nuevamente.');
          return;
        }
        endpoint = baseUrl + '/functions/v1/catalog-read';
        headers = { apikey: publishableKey, authorization: 'Bearer ' + data.session.access_token };
      }
      if (generation !== sessionGeneration) return;
      const response = await fetch(endpoint, { cache: 'no-store', credentials: 'omit', headers, signal: controller.signal });
      if (generation !== sessionGeneration) return;
      if (hosted && (response.status === 401 || response.status === 403)) {
        await signOut('Tu sesión no tiene acceso al catálogo. Contacta a la persona administradora.');
        return;
      }
      if (!response.ok) throw new Error('No se pudo consultar el catálogo.');
      const data = await response.json();
      if (generation !== sessionGeneration) return;
      if (!Array.isArray(data.representations) || !Array.isArray(data.runs)) throw new Error('Respuesta inválida');
      catalog = data;
      lastRead = new Date();
      error = '';
    } catch {
      if (generation === sessionGeneration) {
        error = hosted ? 'No se pudo actualizar la vista. Inténtalo nuevamente.'
          : 'No se pudo actualizar la vista. Comprueba que el servidor local y Supabase estén en ejecución.';
      }
    } finally {
      if (generation === sessionGeneration) {
        loading = false;
        currentRequest = undefined;
      }
    }
  }
  onMount(() => {
    if (hosted) {
      try {
        const url = new URL(import.meta.env.VITE_CATALOG_SUPABASE_URL);
        const validHttp = url.protocol === 'https:' || (url.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(url.hostname));
        const key = import.meta.env.VITE_CATALOG_SUPABASE_PUBLISHABLE_KEY;
        if (!validHttp || url.origin !== url.href.replace(/\/$/, '')) throw new Error('URL');
        if (!key?.startsWith('sb_publishable_')) throw new Error('publishable');
        baseUrl = url.origin;
        publishableKey = key;
        client = createClient(baseUrl, publishableKey, {
          auth: { persistSession: false, autoRefreshToken: true, detectSessionInUrl: false },
        });
        client.auth.onAuthStateChange(event => {
          if (event === 'SIGNED_OUT' && signedIn) {
            endSession('La sesión terminó. Inicia sesión nuevamente.');
            void tick().then(() => emailInput?.focus());
          }
        });
      } catch (cause) {
        const variable = cause instanceof Error && cause.message === 'publishable'
          ? 'VITE_CATALOG_SUPABASE_PUBLISHABLE_KEY' : 'VITE_CATALOG_SUPABASE_URL';
        configurationError = `Revisa ${variable} en .env.development.local y reinicia npm run dev.`;
      }
    } else if (panelMode !== 'local') {
      configurationError = 'Configura VITE_CATALOG_PANEL_MODE=hosted en .env.development.local y reinicia npm run dev.';
    } else {
      void refresh();
    }
    const timer = setInterval(() => { if (!document.hidden) void refresh(); }, 60_000);
    const onVisible = () => { if (!document.hidden) void refresh(); };
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      sessionGeneration++;
      currentRequest?.abort();
      clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisible);
      void client?.auth.dispose();
    };
  });
</script>

<svelte:head><title>Catálogo | SMMUN</title></svelte:head>
<main>
  <header>
    <div><p class="eyebrow">SMMUN · CONSULTA INTERNA</p><h1>Catálogo de representaciones</h1><p>Consulta las opciones y el estado de la sincronización.</p></div>
    {#if !hosted || signedIn}
      <div class="actions"><button bind:this={refreshButton} onclick={refresh} disabled={loading}>{loading ? 'Actualizando…' : 'Actualizar vista'}</button>{#if hosted}<button class="secondary" onclick={() => signOut()}>Cerrar sesión</button>{/if}</div>
    {/if}
  </header>
  {#if configurationError}
    <p class="error" role="alert">{configurationError}</p>
  {:else if hosted && !signedIn}
    <section class="login" aria-labelledby="login-title">
      <h2 id="login-title">Iniciar sesión</h2>
      <p>Ingresa con una cuenta autorizada para consultar el catálogo.</p>
      {#if authError}<p class="error" role="alert">{authError}</p>{/if}
      <form onsubmit={signIn}>
        <label>Correo electrónico<input type="email" autocomplete="username" bind:this={emailInput} bind:value={email} required /></label>
        <label>Contraseña<input type="password" autocomplete="current-password" bind:value={password} required /></label>
        <button type="submit" disabled={!client || signingIn || signingOut}>{signingIn ? 'Ingresando…' : 'Ingresar'}</button>
      </form>
    </section>
  {:else}
  {#if error}<p class="error" role="alert">{error}{#if lastRead} Última consulta correcta: {date(lastRead)}.{/if}</p>{/if}
  {#if catalog && editions.length === 0}<p role="status">Aún no hay representaciones ni corridas. Ejecuta la primera vista previa de la hoja de staging.</p>{/if}
  {#each summaries as { edition: value, latest, completed, applied, schedule } (value)}
  <section class="monitor" aria-label={`Sincronización de ${value}`}>
    <h2>{value}</h2>
    <p>{catalog?.schedules === undefined ? 'Estado de programación desconocido' : !schedule ? 'Pruebas manuales' : schedule.active ? 'Programada cada 20 minutos' : 'Programación pausada'}</p>
    {#if schedule?.overdue}<p class="error" role="status">Sincronización atrasada. Comprueba el trabajo de Cron y la respuesta de la función en staging.</p>{/if}
    {#if completed?.status === 'review'}<p class="error" role="status">Requiere revisión. Concilia las ausencias o renombres en la hoja y repite la vista previa.</p>
    {:else if completed?.status === 'error'}<p class="error" role="status">Falló la sincronización. Revisa la corrida{completed.error_code ? ` (${completed.error_code})` : ''} y ejecuta una vista previa antes de reanudar.</p>{/if}
  <div class="summary">
    <div><span>Última corrida</span><strong>{latest ? label(latest) : 'Sin sincronizaciones'}</strong><small>{date(latest?.started_at)}</small></div>
    <div><span>Última aplicación</span><strong>{date(applied?.finished_at)}</strong></div>
    <div><span>Resultado de la última corrida</span>{#if latest && latest.altas !== null}<strong>{latest.altas} altas · {latest.cambios} cambios · {latest.iguales} iguales · {latest.ausentes} ausentes</strong>{:else}<strong>Sin datos</strong>{/if}</div>
  </div>
  </section>
  {/each}
  <section class="catalog" aria-labelledby="catalog-title">
    <div class="section-heading"><h2 id="catalog-title">Representaciones</h2><p>{rows.length} opciones</p></div>
    <div class="filters">
      <label>Edición <select bind:value={edition} onchange={() => { committee = ''; }}><option value="">Todas</option>{#each editions as value}<option {value}>{value}</option>{/each}</select></label>
      <label>Comité <select bind:value={committee}><option value="">Todos</option>{#each committees as value}<option {value}>{value}</option>{/each}</select></label>
    </div>
    {#if !catalog && loading}<p role="status">Cargando catálogo…</p>
    {:else if catalog && rows.length === 0}<p>No hay representaciones para esta selección.</p>
    {:else if catalog}
      <!-- svelte-ignore a11y_no_noninteractive_tabindex: permite desplazar la tabla con el teclado -->
      <div class="table-wrap" tabindex="0" role="region" aria-label="Tabla de representaciones, desplazable horizontalmente">
        <table><thead><tr><th>Edición</th><th>Comité</th><th>Representación</th><th>Tipo</th><th>Codelegación</th><th>Disponibilidad</th></tr></thead>
          <tbody>{#each rows as row (row.id)}<tr><td>{row.edition}</td><td>{row.committee}</td><td>{row.representation_name}</td><td>{row.representation_type}</td><td>{row.allows_co_delegation ? 'Sí' : 'No'}</td><td><span class:available={row.disponible} class="badge">{row.disponible ? 'Disponible' : 'No disponible'}</span></td></tr>{/each}</tbody>
        </table>
      </div>
    {/if}
  </section>
  {/if}
</main>
<style>
  :global(html) { font-family: system-ui, sans-serif; color: #190f5b; background: #fffdf8; }
  :global(body) { margin: 0; }
  main { max-width: 76rem; margin: 0 auto; padding: 3rem 1.25rem; }
  header { display: flex; justify-content: space-between; align-items: end; gap: 1.5rem; margin-bottom: 2rem; }
  h1 { font-size: clamp(1.8rem, 4vw, 2.8rem); margin: .3rem 0; }
  h2 { font-size: 1.25rem; margin: 0; } p { line-height: 1.5; }
  header p, .section-heading p { color: #595575; margin: .35rem 0; }
  .eyebrow { font-size: .75rem; letter-spacing: .12em; font-weight: 750; }
  button { border: 0; border-radius: .5rem; padding: .8rem 1rem; color: white; background: #281a75; font: inherit; font-weight: 650; cursor: pointer; white-space: nowrap; }
  button:disabled { opacity: .65; cursor: wait; }
  .actions { display: flex; flex-wrap: wrap; gap: .5rem; }
  .secondary { color: #281a75; background: white; border: 1px solid #b5aec9; }
  .login { max-width: 28rem; padding: 1.5rem; background: white; border: 1px solid #dfdbe9; border-radius: .75rem; }
  .login p { color: #595575; }
  .login .error { color: #802627; }
  form { display: grid; gap: 1rem; }
  input { box-sizing: border-box; width: 100%; padding: .65rem; background: white; border: 1px solid #aba4c2; border-radius: .4rem; color: inherit; font: inherit; }
  :global(:focus-visible) { outline: 3px solid #a17514; outline-offset: 3px; }
  .summary { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1px; background: #dfdbe9; border: 1px solid #dfdbe9; border-radius: .75rem; overflow: hidden; }
  .summary div { background: white; padding: 1.2rem; display: grid; gap: .5rem; }
  .summary span, small { color: #595575; font-size: .85rem; }
  .summary strong { line-height: 1.45; }
  .monitor { margin: 1.5rem 0; }
  .monitor h2 { overflow-wrap: anywhere; }
  .catalog { margin-top: 2rem; background: white; border: 1px solid #dfdbe9; border-radius: .75rem; padding: 1.25rem; }
  .filters { display: flex; gap: 1rem; flex-wrap: wrap; margin: 1rem 0; }
  label { display: grid; gap: .35rem; font-size: .9rem; font-weight: 650; }
  select { min-width: 12rem; max-width: 100%; padding: .55rem; background: white; border: 1px solid #aba4c2; border-radius: .4rem; color: inherit; font: inherit; }
  .table-wrap { overflow-x: auto; } table { border-collapse: collapse; width: 100%; text-align: left; font-size: .9rem; }
  th, td { padding: .85rem; border-bottom: 1px solid #eceaf2; } th { color: #595575; white-space: nowrap; }
  .badge { display: inline-block; white-space: nowrap; background: #eeeaf1; color: #54455d; border-radius: 1rem; padding: .25rem .6rem; }
  .available { color: #165d3b; background: #e1f4e9; }
  .error { color: #802627; background: #fff0ef; border: 1px solid #efc7c3; padding: 1rem; border-radius: .5rem; }
  @media (max-width: 650px) { header { align-items: start; flex-direction: column; } .summary { grid-template-columns: 1fr; } .filters label, select { width: 100%; } }
</style>
