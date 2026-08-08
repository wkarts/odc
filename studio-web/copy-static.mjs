import { copyFileSync } from 'node:fs';
for (const file of ['index.html','style.css','icon.png']) copyFileSync(`./src/${file}`, `./dist/${file}`);
