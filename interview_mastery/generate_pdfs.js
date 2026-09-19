const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const inputDir = __dirname;
const outputDir = path.join(inputDir, 'pdf');
const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const fileMap = [
  { in: 'README.md', out: '00_README_Interview_Mastery_Hub.pdf', title: 'Interview Mastery Hub' },
  { in: 'interview_study_schedule.md', out: '01_Interview_Study_Schedule.pdf', title: '3-Day Study Schedule & Hourly Timetable' },
  { in: 'senior_flutter_interview_master_guide.md', out: '02_Senior_Flutter_Interview_Master_Guide.pdf', title: 'Senior Flutter Interview Master Guide' },
  { in: 'flutter_interview_qa_and_coding_master.md', out: '03_Flutter_Interview_QA_and_Coding_Master_Vol1.pdf', title: 'Flutter Interview Q&A & Coding Master (Vol 1)' },
  { in: 'flutter_interview_master_vol2.md', out: '04_Flutter_Interview_Master_Vol2_System_Design.pdf', title: 'System Design & Flutter Engine (Vol 2)' },
  { in: 'flutter_interview_master_vol3.md', out: '05_Flutter_Interview_Master_Vol3_Edge_Scenarios.pdf', title: 'Edge Scenarios, Hardcore Dart & Slivers (Vol 3)' },
  { in: 'senior_flutter_zero_blindspots.md', out: '06_Senior_Flutter_Zero_Blindspots_Final_Polish.pdf', title: 'Zero Blindspots Final Polish' },
  { in: 'senior_portal_mobile_live_coding_master.md', out: '07_Senior_Portal_and_Mobile_Live_Coding_Master.pdf', title: 'Portal & Mobile Live Coding Master' },
  { in: 'dart_algorithms_and_logic_master.md', out: '08_Dart_Algorithms_and_Data_Structures_Master.pdf', title: 'Dart Algorithms & Data Structures Master' },
  { in: 'pure_logic_coding_interview_master.md', out: '09_Pure_Logic_Coding_Interview_Master.pdf', title: 'Pure Logic Coding Interview Master' },
  { in: 'senior_flutter_coding_audit_and_capstone.md', out: '10_Senior_Flutter_Coding_Audit_and_Capstone.pdf', title: 'Coding Curriculum Audit & Capstone' },
  { in: 'senior_flutter_behavioral_master.md', out: '11_Senior_Flutter_Behavioral_Master_STAR.pdf', title: 'Senior Behavioral Master (STAR Framework)' },
  { in: 'senior_flutter_interview_process_and_playbook.md', out: '12_Senior_Flutter_Interview_Process_and_Playbook.pdf', title: 'Interview Process, Negotiation & Execution Playbook' }
];

const cssStyle = `
  @page {
    size: A4;
    margin: 18mm 15mm 18mm 15mm;
  }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 13px;
    line-height: 1.55;
    color: #1f2328;
    background-color: #ffffff;
    margin: 0;
    padding: 0;
  }
  h1 {
    font-size: 22px;
    border-bottom: 2px solid #0969da;
    padding-bottom: 6px;
    margin-top: 20px;
    margin-bottom: 12px;
    color: #0969da;
    page-break-after: avoid;
  }
  h2 {
    font-size: 17px;
    border-bottom: 1px solid #d0d7de;
    padding-bottom: 5px;
    margin-top: 18px;
    margin-bottom: 10px;
    color: #1f2328;
    page-break-after: avoid;
  }
  h3 {
    font-size: 14px;
    margin-top: 15px;
    margin-bottom: 8px;
    color: #1f2328;
    page-break-after: avoid;
  }
  p, ul, ol {
    margin-top: 0;
    margin-bottom: 10px;
  }
  li {
    margin-bottom: 3px;
  }
  code {
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace;
    font-size: 11.5px;
    background-color: #eff1f3;
    padding: 2px 4px;
    border-radius: 4px;
    color: #0550ae;
  }
  pre {
    background-color: #f6f8fa;
    border: 1px solid #d0d7de;
    border-radius: 6px;
    padding: 10px;
    overflow-x: auto;
    font-size: 11px;
    line-height: 1.4;
    page-break-inside: avoid;
    margin-bottom: 12px;
  }
  pre code {
    background: transparent;
    padding: 0;
    color: #24292f;
  }
  blockquote {
    border-left: 4px solid #0969da;
    background-color: #f0f7ff;
    padding: 8px 12px;
    margin: 0 0 12px 0;
    border-radius: 0 6px 6px 0;
    color: #0969da;
    page-break-inside: avoid;
  }
  blockquote p {
    margin-bottom: 0;
    color: #1f2328;
  }
  table {
    border-collapse: collapse;
    width: 100%;
    margin-bottom: 14px;
    page-break-inside: avoid;
    font-size: 11.5px;
  }
  th, td {
    border: 1px solid #d0d7de;
    padding: 6px 8px;
    text-align: left;
  }
  th {
    background-color: #f6f8fa;
    font-weight: 600;
  }
  tr:nth-child(even) {
    background-color: #fcfdfe;
  }
  hr {
    height: 1px;
    background-color: #d0d7de;
    border: none;
    margin: 18px 0;
  }
  .doc-header {
    background: linear-gradient(135deg, #0969da 0%, #033d8b 100%);
    color: white;
    padding: 12px 16px;
    border-radius: 6px;
    margin-bottom: 18px;
  }
  .doc-header h2 {
    color: white;
    border-bottom: none;
    margin: 0;
    padding: 0;
    font-size: 17px;
  }
  .doc-header p {
    margin: 4px 0 0 0;
    opacity: 0.9;
    font-size: 11.5px;
    color: #e6f0ff;
  }
`;

console.log(`Starting PDF conversion for ${fileMap.length} documents...`);

for (const item of fileMap) {
  const mdPath = path.join(inputDir, item.in);
  const pdfPath = path.join(outputDir, item.out);
  const tempHtmlPath = path.join('/tmp', `${item.in}.html`);

  if (!fs.existsSync(mdPath)) {
    console.warn(`[Skip] File not found: ${item.in}`);
    continue;
  }

  process.stdout.write(`Converting ${item.in} -> ${item.out}... `);

  try {
    const rawHtml = execSync(`npx -y marked -i "${mdPath}" --gfm`).toString();

    const fullHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${item.title}</title>
  <style>${cssStyle}</style>
</head>
<body>
  <div class="doc-header">
    <h2>${item.title}</h2>
    <p>Candidate: Irshath Ahamed | Senior Flutter Developer (Portal/Mobile)</p>
  </div>
  ${rawHtml}
</body>
</html>`;

    fs.writeFileSync(tempHtmlPath, fullHtml);

    const chromeCmd = `"${chromePath}" --headless --disable-gpu --print-to-pdf="${pdfPath}" --no-pdf-header-footer "${tempHtmlPath}"`;
    execSync(chromeCmd, { stdio: 'ignore' });

    if (fs.existsSync(tempHtmlPath)) {
      fs.unlinkSync(tempHtmlPath);
    }

    const stats = fs.statSync(pdfPath);
    console.log(`✓ Done (${Math.round(stats.size / 1024)} KB)`);
  } catch (err) {
    console.error(`✗ Failed: ${err.message}`);
  }
}

console.log('\\nAll PDF files successfully generated in: ' + outputDir);
