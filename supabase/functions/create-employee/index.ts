// supabase/functions/create-employee/index.ts
// Edge Function para crear un nuevo empleado.
// Usa la clave service_role (segura, solo en el servidor) para crear el usuario en Supabase Auth
// y luego registra el empleado en la tabla `employees`.

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
    // 1. Verificar que el que llama es el dueño del negocio
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

    // 2. Verificar que el usuario tiene un negocio (es dueño)
    const { data: business, error: bizError } = await userClient
      .from('businesses')
      .select('id')
      .eq('user_id', user.id)
      .single()

    if (bizError || !business) {
      return new Response(JSON.stringify({ error: 'No tienes permiso para crear empleados' }), { status: 403, headers: corsHeaders })
    }

    // 3. Obtener datos del formulario
    const { firstName, lastName, email, password } = await req.json()

    if (!firstName || !email || !password) {
      return new Response(JSON.stringify({ error: 'Nombre, correo y contraseña son obligatorios' }), { status: 400, headers: corsHeaders })
    }

    // 4. Crear el usuario en Supabase Auth usando el cliente admin (service_role)
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: newUser, error: createError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // Confirmar el correo automáticamente, sin que reciba email
      user_metadata: {
        first_name: firstName,
        last_name: lastName ?? '',
      },
    })

    if (createError) {
      return new Response(JSON.stringify({ error: createError.message }), { status: 400, headers: corsHeaders })
    }

    // 5. Registrar el empleado en la tabla `employees`
    const { error: empError } = await adminClient
      .from('employees')
      .insert({
        business_id: business.id,
        user_id: newUser.user!.id,
        name: `${firstName} ${lastName ?? ''}`.trim(),
        role: 'operator',
        is_active: true,
      })

    if (empError) {
      // Si falla el INSERT, borrar el usuario auth para no dejar registros huérfanos
      await adminClient.auth.admin.deleteUser(newUser.user!.id)
      return new Response(JSON.stringify({ error: empError.message }), { status: 500, headers: corsHeaders })
    }

    return new Response(
      JSON.stringify({ success: true, employeeId: newUser.user!.id }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: corsHeaders })
  }
})
