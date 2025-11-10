import * as fs from "fs";

const filterFields = (issue) => {
  return {
    number: issue.number,
    title: issue.title,
    created_at: issue.created_at,
    updated_at: issue.updated_at,
    closed_at: issue.closed_at,
    pull_request: issue.pull_request?.url,
    labels: issue.labels.map(label => label.name),
    state: issue.state,
  };
};

const nodes = JSON.parse(fs.readFileSync("scripts/content/tinymist-issues-2024-2025.json", "utf8"))
    .map(filterFields);

fs.writeFileSync("scripts/content/tinymist-issues-2024-2025-trim.json", JSON.stringify(nodes, null, 2));