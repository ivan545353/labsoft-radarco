// supabase/functions/analizar-foto/index.ts
//
// Edge Function proxy para Gemini Vision (RadarCO).
// Recibe una foto + la categoría elegida por el usuario + las categorías
// válidas, y devuelve un JSON con la categoría sugerida, confianza y
// plausibilidad. La API key NUNCA toca el cliente: vive como secreto.
//
// Deploy:
//   supabase secrets set GEMINI_API_KEY=AIza...
//   supabase functions deploy analizar-foto

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

// Cambiá al modelo Flash más nuevo que veas en la pricing page (ej: gemini-3.5-flash).
const MODELO = "gemini-3.1-flash-lite";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  // Preflight CORS (necesario para Flutter Web)
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!GEMINI_API_KEY) {
      throw new Error("Falta el secreto GEMINI_API_KEY");
    }

    const { imagen_base64, categoria_elegida, categorias_validas } =
      await req.json();

    if (
      !imagen_base64 ||
      !categoria_elegida ||
      !Array.isArray(categorias_validas)
    ) {
      return json({ error: "Parámetros inválidos" }, 400);
    }

    const prompt = `
Sos un clasificador de reportes ciudadanos urbanos para una app de la ciudad de Caleta Olivia, Argentina.
Analizá la imagen adjunta. El usuario la clasificó manualmente como: "${categoria_elegida}".

Categorías válidas (elegí EXACTAMENTE una de esta lista para "categoria_sugerida"):
${categorias_validas.map((c: string) => `- ${c}`).join("\n")}

Reglas para "es_plausible":
- Poné es_plausible=false SOLO si la imagen claramente NO es un reporte urbano: selfies o personas como tema principal, memes, capturas de pantalla, contenido sexual/obsceno, violencia gráfica, o fotos sin relación con la vía pública.
- Ante la duda, o si se ve cualquier elemento plausible de la vía pública (calles, veredas, edificios, autos, postes, basura, etc.), poné es_plausible=true.

Devolvé SOLO un objeto JSON con esta forma exacta, sin texto adicional ni markdown:
{
  "categoria_sugerida": "<una de las categorías válidas que mejor describe lo que se ve>",
  "confianza": <número entre 0 y 1>,
  "es_plausible": <true/false según las reglas de arriba>,
  "motivo": "<explicación breve en una frase, en español>"
}
`.trim();

    const geminiResp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODELO}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: prompt },
                {
                  inline_data: {
                    mime_type: "image/jpeg",
                    data: imagen_base64,
                  },
                },
              ],
            },
          ],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.1,
          },
        }),
      },
    );

    if (!geminiResp.ok) {
      const detalle = await geminiResp.text();
      return json({ error: "Error de Gemini", detalle }, 502);
    }

    const data = await geminiResp.json();
    const texto = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    // Parseo defensivo (por si viniera con fences ```json)
    const limpio = texto.replace(/```json/gi, "").replace(/```/g, "").trim();

    let resultado;
    try {
      resultado = JSON.parse(limpio);
    } catch (_e) {
      return json({ error: "Respuesta no parseable", crudo: texto }, 500);
    }

    return json(resultado, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}