const fs = require('fs');
const path = require('path');
const Packager = require('@turbowarp/packager');

const run = async () => {
  const inputFile = process.argv[2] || path.join(__dirname, '_GAME_pkg.sb3');
  const outputDir  = path.join(__dirname, 'output');
  const outputFile = path.join(outputDir, 'index.html');

  if (!fs.existsSync(inputFile)) {
    console.error(`Error: input file not found: ${inputFile}`);
    process.exit(1);
  }

  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir);

  console.log('Reading sb3 file...');
  const projectData = fs.readFileSync(inputFile);

  console.log('Loading project...');
  const loadedProject = await Packager.loadProject(projectData, (type, a, b) => {
    if (b) process.stdout.write(`\r  ${type}: ${a}/${b}   `);
    else process.stdout.write(`\r  ${type}: ${Math.round(a * 100)}%   `);
  });
  console.log('\nPackaging...');

  const packager = new Packager.Packager();
  packager.project = loadedProject;

  const result = await packager.package();
  fs.writeFileSync(outputFile, result.data);
  console.log(`Done! Output: ${outputFile} (${(result.data.length / 1024 / 1024).toFixed(2)} MB)`);
};

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
