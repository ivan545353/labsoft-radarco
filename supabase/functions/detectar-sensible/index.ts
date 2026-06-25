// supabase/functions/detectar-sensible/index.ts
//
// Detecta rostros y patentes en una foto y devuelve sus bounding boxes
// normalizadas (0..1000) para que el cliente las pixele ANTES de subir (HU7.3).
//
// Deploy:
//   supabase functions deploy detectar-sensible
// (usa el mismo secreto GEMINI_API_KEY que analizar-foto)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

// Probás con lite; si la localización de cajas falla, subí a un Flash normal.
const MODELO = "gemini-3.1-flash-lite";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!GEMINI_API_KEY) throw new Error("Falta el secreto GEMINI_API_KEY");

    const { imagen_base64 } = await req.json();
    if (!imagen_base64) return json({ error: "Falta imagen_base64" }, 400);

    const prompt = `
Detectá en la imagen TODAS las caras humanas reconocibles y TODAS las patentes
(matrículas) de vehículos.

Devolvé SOLO un objeto JSON con esta forma exacta, sin texto extra ni markdown:
{ "regiones": [ [ymin, xmin, ymax, xmax] ] }

Reglas:
- Cada caja en coordenadas ENTERAS normalizadas de 0 a 1000, donde (ymin, xmin)
  es la esquina superior izquierda y (ymax, xmax) la inferior derecha.
- Una caja por cada cara y una por cada patente visible.
- NO incluyas nada que no sea una cara humana o una patente.
- Si no hay ninguna, devolvé { "regiones": [] }.
`.trim();

    const resp = await fetch(
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
            temperature: 0,
          },
        }),
      },
    );

    if (!resp.ok) {
      const detalle = await resp.text();
      return json({ error: "Error de Gemini", detalle }, 502);
    }

    const data = await resp.json();
    const texto = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const limpio = texto.replace(/```json/gi, "").replace(/```/g, "").trim();

    let parsed;
    try {
      parsed = JSON.parse(limpio);
    } catch (_e) {
      return json({ regiones: [] }, 200); // ante duda, no rompemos el flujo
    }

    const regiones = Array.isArray(parsed?.regiones) ? parsed.regiones : [];
    return json({ regiones }, 200);
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