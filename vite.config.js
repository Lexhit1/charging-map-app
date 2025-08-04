import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';
import { NodeGlobalsPolyfillPlugin } from '@esbuild-plugins/node-globals-polyfill';

export default defineConfig({
  plugins: [
    // Laravel + Vue
    laravel({
      input: [
        'resources/css/app.css',
        'resources/js/app.js',
      ],
      refresh: true,
    }),
    vue({
      template: {
        transformAssetUrls: {
          base: null,
          includeAbsolute: false,
        },
      },
    }),
    // Polyfill для Node.js globals
    {
      ...NodeGlobalsPolyfillPlugin({
        buffer: true,
        process: true,
      }),
      enforce: 'post', // важно задать порядок
    },
  ],

  resolve: {
    alias: {
      crypto: 'crypto-browserify',
      vue: 'vue/dist/vue.esm-bundler.js',
    },
  },

  server: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
        secure: false,
      },
    },
  },

  build: {
    manifest: true,
    outDir: 'public/build',
    rollupOptions: {
      external: ['crypto'],
    },
  },
});
