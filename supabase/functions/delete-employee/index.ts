// supabase/functions/delete-employee/index.ts
// Edge Function para eliminar un empleado.
// Borra el registro de `employees` y la cuenta en Supabase Auth.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')!
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await userClient.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'No autenticado' }), { status: 401, headers: corsHeaders })
    }

    // Verificar que el usuario es dueño
    const { data: business } = await userClient
      .from('businesses')
      .select('id')
      .eq('user_id', user.id)
      .single()

    if (!business) {
      return new Response(JSON.stringify({ error: 'Sin permiso' }), { status: 403, headers: corsHeaders })
    }

    const { employeeUserId } = await req.json()

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Verificar que el empleado pertenece al negocio antes de borrar
    const { data: emp } = await adminClient
      .from('employees')
      .select('id')
      .eq('user_id', employeeUserId)
      .eq('business_id', business.id)
      .single()

    if (!emp) {
      return new Response(JSON.stringify({ error: 'Empleado no encontrado' }), { status: 404, headers: corsHeaders })
    }

    // Borrar registro y cuenta
    await adminClient.from('employees').delete().eq('user_id', employeeUserId)
    await adminClient.auth.admin.deleteUser(employeeUserId)

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: corsHeaders })
  }
})
