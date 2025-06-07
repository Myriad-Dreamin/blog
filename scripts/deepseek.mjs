import { OpenAI } from "openai";
import { loadEnv } from "vite";
import fs from "fs/promises";

const e = loadEnv("production", process.cwd(), "");

const openai = new OpenAI({
  baseURL: "https://api.deepseek.com/v1",
  apiKey: e.DEEPSEEK_API_KEY,
});

export const createCompletion = async (message, language = "Chinese") => {
  try {
    const completion = await openai.chat.completions.create({
      messages: [
        {
          role: "system",
          content: `You are a knowledgeable translator that translate text in user documents sentence by sentence. Translate following Typst (A markup) to ${language} (only output same syntax) without extra wrapping. Please keep markup to avoid syntax error.`,
        },
        { role: "user", content: message },
      ],
      model: "deepseek-reasoner",
      temperature: 1.3,
    });

    return completion.choices[0].message.content;
  } catch (error) {
    throw new Error("Completion failed: " + error.message);
  }
};

const fileName = process.argv[2];
if (!fileName) {
  console.error("Please provide a file name as an argument.");
  process.exit(1);
}

const output = process.argv[3];
if (!output) {
  console.error("Please provide an output file name as an argument.");
  process.exit(1);
}

const language = output.includes("/zh/") ? "Chinese" : "English";
console.log(`Translating to ${language}...`);

const fileContent = await fs.readFile(fileName, "utf-8");
const translated = await createCompletion(fileContent, language);
await fs.writeFile(output, translated, "utf-8");
console.log(`Translation completed and saved to ${output}`);
