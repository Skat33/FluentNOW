import {headers} from 'next/headers';
import {z} from 'zod';
import {claimReports,resolveReport,reviewStatus} from '@/lib/report-store';
import {correctionPatchSchema} from '@/lib/report-corrections';
// Service writer for this OWNER-PRIVATE Site. Dispatch validates and consumes the
// Site service credential; it does not forward a visitor ID. Never expose this
// endpoint on a public Site without adding dedicated service authorization.
async function blocked(req:Request){return !!req.headers.get('origin') || !!(await headers()).get('oai-authenticated-user-id');}
export async function GET(req:Request){if(await blocked(req))return new Response(null,{status:403});return Response.json(await reviewStatus(),{headers:{'Cache-Control':'no-store'}});}
export async function POST(req:Request){if(await blocked(req))return new Response(null,{status:403});try{return Response.json(await claimReports(),{headers:{'Cache-Control':'no-store'}});}catch{return Response.json({error:'Review queue unavailable; no decisions were deleted.'},{status:503});}}
const decision=z.object({id:z.string().uuid(),token:z.string().uuid(),verdict:z.enum(['confirmed','dismissed','uncertain']),reason:z.string().min(1).max(2000),verified:z.boolean(),patch:correctionPatchSchema.optional()});
export async function PATCH(req:Request){if(await blocked(req))return new Response(null,{status:403});try{const raw=await req.text();if(raw.length>50000)return new Response(null,{status:413});return Response.json(await resolveReport(decision.parse(JSON.parse(raw))));}catch{return Response.json({error:'Invalid or stale decision; retained for review.'},{status:409});}}
