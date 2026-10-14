import { withSupabase } from 'npm:@supabase/server@1.9.2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type InviteBody = {
  email?: unknown
  full_name?: unknown
  license_number?: unknown
}

function response(status: number, payload: Record<string, unknown>) {
  return Response.json(payload, { status, headers: corsHeaders })
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (req.method !== 'POST') return response(405, { message: 'Método no permitido.' })

    const claims = ctx.userClaims as { id?: string; sub?: string } | undefined
    const adminId = claims?.id ?? claims?.sub
    if (!adminId) return response(401, { message: 'Sesión no válida.' })

    const aal = (ctx.jwtClaims as { aal?: string } | undefined)?.aal
    if (aal !== 'aal2') {
      return response(403, {
        message: 'Verifica el segundo factor antes de invitar conductores.',
      })
    }

    const { data: profile, error: profileError } = await ctx.supabase
      .from('profiles')
      .select('role')
      .eq('id', adminId)
      .maybeSingle()

    if (profileError || profile?.role !== 'admin') {
      return response(403, { message: 'Se requieren permisos administrativos.' })
    }

    let body: InviteBody
    try {
      body = (await req.json()) as InviteBody
    } catch {
      return response(400, { message: 'Solicitud JSON no válida.' })
    }

    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : ''
    const fullName = typeof body.full_name === 'string' ? body.full_name.trim() : ''
    const license =
      typeof body.license_number === 'string' && body.license_number.trim()
        ? body.license_number.trim()
        : null

    if (!email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/) || fullName.length < 2) {
      return response(422, { message: 'Nombre o correo no válidos.' })
    }

    const { data: invite, error: inviteError } =
      await ctx.supabaseAdmin.auth.admin.inviteUserByEmail(email, {
        data: { full_name: fullName },
      })

    if (inviteError || !invite.user) {
      return response(409, {
        message: inviteError?.message ?? 'No fue posible crear la invitación.',
      })
    }

    const userId = invite.user.id
    const { error: profileWriteError } = await ctx.supabaseAdmin
      .from('profiles')
      .upsert({ id: userId, email, full_name: fullName, role: 'driver' })

    if (profileWriteError) {
      await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
      return response(500, { message: 'No fue posible preparar el perfil.' })
    }

    const driverId = crypto.randomUUID()
    const { error: driverError } = await ctx.supabaseAdmin
      .from('drivers')
      .upsert({ id: driverId, profile_id: userId, license_number: license, status: 'active' }, {
        onConflict: 'profile_id',
      })

    if (driverError) {
      await ctx.supabaseAdmin.from('profiles').delete().eq('id', userId)
      await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
      return response(500, { message: 'No fue posible preparar al conductor.' })
    }

    const { error: auditError } = await ctx.supabaseAdmin.from('audit_logs').insert({
      admin_user_id: adminId,
      action: 'invite_driver',
      entity_type: 'drivers',
      entity_id: driverId,
      metadata: { source: 'edge_function' },
    })

    if (auditError) {
      await ctx.supabaseAdmin.from('profiles').delete().eq('id', userId)
      await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
      return response(500, { message: 'La invitación no pudo auditarse y fue revertida.' })
    }

    return response(201, { ok: true })
  }),
}
