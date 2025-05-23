import { registerPlugin } from '@capacitor/core';

// Register the HTTP plugin using registerPlugin
const Http = registerPlugin('Http');

// Extend the Window interface to add our custom property
declare global {
  interface Window {
    capacitorPlugins: any;
  }
}

// Export for use in other files
window.capacitorPlugins = {
  Http
};

// Initialize Capacitor
document.addEventListener('DOMContentLoaded', () => {
  console.log('Capacitor plugins initialized:', window.capacitorPlugins);
});
