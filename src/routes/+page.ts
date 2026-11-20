import { resolve } from '$app/paths';
import { redirect } from '@sveltejs/kit';

export function load() {
  if (import.meta.env.DEV) redirect(307, resolve('catalogo/'));
}
