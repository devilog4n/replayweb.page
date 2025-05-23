import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  root: './src',
  build: {
    outDir: '../www',
    minify: false,
    emptyOutDir: false,
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'src/main.ts'),
      },
      output: {
        entryFileNames: 'js/capacitor-plugins.js',
        format: 'iife',
        name: 'capacitorPlugins'
      }
    }
  },
});
