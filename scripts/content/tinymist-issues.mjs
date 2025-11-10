import { execSync } from "child_process";
import fs from "fs";

const allIssues = [];

for (let page = 1; page <= 30; page++) {
  const issues = JSON.parse(execSync(`gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" '/repos/Myriad-Dreamin/tinymist/issues?since=2024-01-01T00:00:00Z&state=all&per_page=100&page=${page}'`));
  console.log(`Downloaded ${issues.length} issues from page ${page}`);
  allIssues.push(...issues);
}

fs.writeFileSync("scripts/content/tinymist-issues-2024-2025.json", JSON.stringify(allIssues, null, 2));
