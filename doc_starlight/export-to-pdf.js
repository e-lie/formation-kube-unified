#!/usr/bin/env node

import puppeteer from 'puppeteer';
import { PDFDocument } from 'pdf-lib';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const CONFIG = {
  baseUrl: 'http://localhost:4321',
  outputDir: path.join(__dirname, 'pdf-exports'),
  outputFile: 'formation-kubernetes-complete.pdf',
  buildDir: path.join(__dirname, 'dist'),
  sections: [
    { name: 'kubernetes-principal', title: 'Cours Principal' },
    { name: 'bonus', title: 'Aspects Avancés' },
    { name: 'gitops-argocd', title: 'GitOps & ArgoCD' },
    { name: 'clusters-onpremise', title: 'Clusters On-Premise' },
    { name: 'microservices-istio', title: 'Microservices & Istio' }
  ]
};

// Fonction pour extraire les pages du sitemap ou parcourir le dossier dist
async function extractPages() {
  const pages = [];
  
  try {
    // Lire le fichier de contenu pour avoir l'ordre correct
    for (const section of CONFIG.sections) {
      const sectionPath = path.join(__dirname, 'src', 'content', 'docs', section.name);
      
      try {
        const files = await fs.readdir(sectionPath);
        const mdFiles = files
          .filter(f => f.endsWith('.md') || f.endsWith('.mdx'))
          .sort(); // Tri alphabétique pour maintenir l'ordre des numéros
        
        for (const file of mdFiles) {
          const pageName = file.replace(/\.(md|mdx)$/, '');
          pages.push({
            url: `${CONFIG.baseUrl}/${section.name}/${pageName}/`,
            path: `/${section.name}/${pageName}/`,
            section: section.title,
            title: pageName
          });
        }
      } catch (err) {
        console.warn(`Section ${section.name} non trouvée, passage...`);
      }
    }
    
    // Ajouter la page d'accueil
    pages.unshift({
      url: CONFIG.baseUrl,
      path: '/',
      section: 'Accueil',
      title: 'index'
    });
    
  } catch (error) {
    console.error('Erreur lors de l\'extraction des pages:', error);
  }
  
  return pages;
}

// Fonction pour démarrer le serveur de développement
async function startServer() {
  console.log('🚀 Démarrage du serveur Astro...');
  const serverProcess = exec('npm run preview', { cwd: __dirname });
  
  // Attendre que le serveur soit prêt
  await new Promise(resolve => setTimeout(resolve, 5000));
  
  return serverProcess;
}

// Fonction pour exporter une page en PDF
async function exportPageToPDF(browser, page, pageInfo, index) {
  console.log(`📄 Export ${index}: ${pageInfo.section} - ${pageInfo.title}`);
  
  try {
    await page.goto(pageInfo.url, { 
      waitUntil: 'networkidle2',
      timeout: 30000 
    });
    
    // Attendre que le contenu soit chargé
    await page.waitForSelector('main', { timeout: 10000 });
    
    // Masquer la sidebar et la navigation pour l'impression
    await page.addStyleTag({
      content: `
        @media print {
          nav, .sidebar, aside, header nav, .toc, [class*="sidebar"] { 
            display: none !important; 
          }
          main, article, [class*="content"] { 
            max-width: 100% !important; 
            margin: 0 !important;
            padding: 20px !important;
          }
          pre { 
            white-space: pre-wrap !important;
            word-wrap: break-word !important;
          }
          code {
            font-size: 10px !important;
          }
        }
      `
    });
    
    // Générer le PDF
    const pdfBuffer = await page.pdf({
      format: 'A4',
      printBackground: true,
      margin: {
        top: '20mm',
        right: '15mm',
        bottom: '20mm',
        left: '15mm'
      },
      displayHeaderFooter: true,
      headerTemplate: `
        <div style="font-size: 10px; text-align: center; width: 100%; margin-top: 10px;">
          <span>${pageInfo.section}</span>
        </div>
      `,
      footerTemplate: `
        <div style="font-size: 10px; text-align: center; width: 100%; margin-bottom: 10px;">
          <span class="pageNumber"></span> / <span class="totalPages"></span>
        </div>
      `
    });
    
    return pdfBuffer;
  } catch (error) {
    console.error(`❌ Erreur lors de l'export de ${pageInfo.title}:`, error.message);
    return null;
  }
}

// Fonction principale
async function main() {
  let serverProcess = null;
  let browser = null;
  
  try {
    // Créer le dossier de sortie
    await fs.mkdir(CONFIG.outputDir, { recursive: true });
    
    // Build du site
    console.log('🔨 Construction du site...');
    await execAsync('npm run build', { cwd: __dirname });
    
    // Démarrer le serveur
    serverProcess = await startServer();
    
    // Extraire la liste des pages
    console.log('📋 Extraction de la liste des pages...');
    const pages = await extractPages();
    console.log(`Found ${pages.length} pages à exporter`);
    
    // Lancer Puppeteer
    console.log('🌐 Lancement du navigateur...');
    browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // Exporter chaque page
    const pdfBuffers = [];
    for (let i = 0; i < pages.length; i++) {
      const pdfBuffer = await exportPageToPDF(browser, page, pages[i], i + 1);
      if (pdfBuffer) {
        pdfBuffers.push(pdfBuffer);
      }
    }
    
    // Fusionner tous les PDFs
    console.log('🔗 Fusion des PDFs...');
    const mergedPdf = await PDFDocument.create();
    
    for (const pdfBuffer of pdfBuffers) {
      const pdf = await PDFDocument.load(pdfBuffer);
      const copiedPages = await mergedPdf.copyPages(pdf, pdf.getPageIndices());
      copiedPages.forEach((page) => mergedPdf.addPage(page));
    }
    
    // Ajouter les métadonnées
    mergedPdf.setTitle('Formation Kubernetes - Documentation Complète');
    mergedPdf.setAuthor('Formation Kubernetes');
    mergedPdf.setSubject('Documentation technique Kubernetes, Helm, Istio');
    mergedPdf.setCreationDate(new Date());
    
    // Sauvegarder le PDF final
    const pdfBytes = await mergedPdf.save();
    const outputPath = path.join(CONFIG.outputDir, CONFIG.outputFile);
    await fs.writeFile(outputPath, pdfBytes);
    
    console.log(`✅ Export terminé ! PDF généré : ${outputPath}`);
    console.log(`📊 Taille du fichier : ${(pdfBytes.length / 1024 / 1024).toFixed(2)} MB`);
    
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  } finally {
    // Nettoyer
    if (browser) await browser.close();
    if (serverProcess) {
      serverProcess.kill();
      console.log('🛑 Serveur arrêté');
    }
  }
}

// Lancer le script
main().catch(console.error);