/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: ['class', '[data-rtrce-theme="mocha"]'],
  theme: {
    extend: {
      colors: {
        'rt-crust': 'var(--rt-crust)',
        'rt-mantle': 'var(--rt-mantle)',
        'rt-base': 'var(--rt-base)',
        'rt-surface-0': 'var(--rt-surface-0)',
        'rt-surface-1': 'var(--rt-surface-1)',
        'rt-surface-2': 'var(--rt-surface-2)',
        'rt-overlay-0': 'var(--rt-overlay-0)',
        'rt-overlay-1': 'var(--rt-overlay-1)',
        'rt-overlay-2': 'var(--rt-overlay-2)',
        'rt-text': 'var(--rt-text)',
        'rt-text-soft': 'var(--rt-text-soft)',
        'rt-text-muted': 'var(--rt-text-muted)',
        'rt-text-faint': 'var(--rt-text-faint)',
        'rt-mauve': 'var(--rt-mauve)',
        'rt-blue': 'var(--rt-blue)',
        'rt-teal': 'var(--rt-teal)',
        'rt-green': 'var(--rt-green)',
        'rt-yellow': 'var(--rt-yellow)',
        'rt-peach': 'var(--rt-peach)',
        'rt-maroon': 'var(--rt-maroon)',
        'rt-red': 'var(--rt-red)',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'Consolas', '"Courier New"', 'monospace'],
      }
    },
  },
  plugins: [],
}
