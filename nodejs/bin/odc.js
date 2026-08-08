#!/usr/bin/env node
import fs from 'node:fs';
import {create,info,verify,extract,setMetadata,removeMetadata} from '../src/odc.js';
const [,,cmd,...a]=process.argv;
try{
 if(cmd==='create'){const m=a[2]?JSON.parse(fs.readFileSync(a[2],'utf8')):{};create(a[0],a[1],m,true);console.log(`Criado: ${a[1]}`)}
 else if(cmd==='info')console.log(JSON.stringify(info(a[0]),null,2));
 else if(cmd==='verify'){const ok=verify(a[0]);console.log(ok?'OK':'INVALIDO');process.exitCode=ok?0:1;}
 else if(cmd==='extract'){extract(a[0],a[1]);console.log(`Extraído: ${a[1]}`)}
 else if(cmd==='set-meta'){setMetadata(a[0],JSON.parse(fs.readFileSync(a[1],'utf8')));console.log('Metadata atualizada.');}
 else if(cmd==='remove-meta'){removeMetadata(a[0]);console.log('Metadata removida.');}
 else throw new Error('Uso: create|info|verify|extract|set-meta|remove-meta');
}catch(e){console.error('ERRO:',e.message);process.exit(1)}
