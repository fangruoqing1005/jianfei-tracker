// Supabase Edge Function: analyze-daily
// 调用 DeepSeek API 生成个性化减脂分析

const DEEPSEEK_API_KEY = Deno.env.get("DEEPSEEK_API_KEY")!;

const STYLE_PROMPTS: Record<string, string> = {
  gentle: "用温暖、共情的语气，像闺蜜聊天一样，多使用'呢''哦''呀'等语气词，让人感到被理解和被关心。",
  firm: "用鞭策、直接的方式，像魔鬼教官一样，指出问题毫不留情，但内心是为她好的。多使用感叹号。",
  cheer: "用积极、打气的方式，像啦啦队长一样，充满能量和正面鼓励。多使用emoji和感叹号。",
  pro: "用冷静、专业的方式，像注册营养师做报告，只基于数据给出客观分析，不添加情绪修饰。",
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { dateStr, profile, records, weeklyAvg, style } = await req.json();

    if (!DEEPSEEK_API_KEY) {
      throw new Error("DEEPSEEK_API_KEY not configured");
    }

    // 构建用户数据摘要
    const startW = profile.startWeight || "未知";
    const targetW = profile.targetWeight || "未知";
    const height = profile.height || "未知";
    const curW = records.length > 0 && records[records.length - 1].weight
      ? records[records.length - 1].weight : "未知";
    const lost = (startW !== "未知" && curW !== "未知")
      ? (parseFloat(startW as string) - parseFloat(curW as string)).toFixed(2) : "未知";

    // 构建7天数据摘要
    let recordsSummary = "";
    for (const r of records.slice(-7)) {
      const data = r.data || {};
      const weight = data.weight ? data.weight + "kg" : "未记录";
      const exercise = (data.exercise || []).join("、") || "无";
      const sleep = data.sleep || "未记录";
      const salt = data.salt || "未记录";
      const carbs = data.carbs || "未记录";
      const water = data.water ? data.water + "ml" : "未记录";
      const bowel = data.bowel !== undefined ? (data.bowel ? "已排便" : "未排便") : "未记录";
      const note = data.note || "";
      const menstrual = data.menstrual ? ("处于" + (data.menstrual.phase || "未知阶段")) : "无";

      recordsSummary += [
        `${r.date}: 体重${weight}，运动[${exercise}]，睡眠${sleep}，盐分${salt}，碳水${carbs}，饮水${water}，${bowel}，经期[${menstrual}]`,
        note ? `备注: ${note}` : "",
      ].filter(Boolean).join("，") + "\n";
    }

    const prompt = `你是一位专业的减脂教练。请根据以下用户数据给出分析和建议。

【用户档案】
起始体重: ${startW}kg，目标体重: ${targetW}kg，身高: ${height}cm
当前体重: ${curW}kg，已减: ${lost}kg
${weeklyAvg ? `本周平均体重: ${weeklyAvg}kg` : ""}

【近7天记录】
${recordsSummary || "暂无记录数据"}

【分析要求】
1. 结合体重趋势分析减脂进展
2. 指出生活习惯中影响减脂的关键因素（睡眠、饮水、运动、饮食、经期等）
3. 给出今天具体可执行的建议

【风格指令】
${STYLE_PROMPTS[style] || STYLE_PROMPTS.gentle}

【输出格式 — 必须严格遵守以下JSON格式，不要输出其他内容】
{
  "headline": "一句话总结，≤25字",
  "body": "核心分析，≤150字，连贯自然的一段话",
  "tips": ["建议1，≤25字", "建议2，≤25字", "建议3，≤25字"],
  "mood": "一个emoji"
}`;

    const response = await fetch("https://api.deepseek.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${DEEPSEEK_API_KEY}`,
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.7,
        max_tokens: 600,
      }),
    });

    const result = await response.json();

    if (result.error) {
      throw new Error(`DeepSeek API error: ${result.error.message}`);
    }

    const content = result.choices?.[0]?.message?.content || "";
    // 尝试从回复中提取 JSON
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error("Failed to parse AI response as JSON");
    }
    const parsed = JSON.parse(jsonMatch[0]);

    return new Response(
      JSON.stringify({ success: true, data: parsed }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
