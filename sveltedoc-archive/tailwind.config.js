/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts,md,svx}'],
  theme: {
    extend: {
      colors: {
        // Svelte official colors
        'svelte': {
          50: '#fff4f0',
          100: '#ffe3d6',
          200: '#ffc2a8',
          300: '#ff9a7a',
          400: '#ff7043',
          500: '#ff3e00', // Primary Svelte orange
          600: '#e6380a',
          700: '#cc2f14',
          800: '#b3261c',
          900: '#991f1f'
        },
        // Grays used in Svelte docs
        'svelte-gray': {
          50: '#fafafa',
          100: '#f5f5f5',
          200: '#eeeeee',
          300: '#e0e0e0',
          400: '#bdbdbd',
          500: '#9e9e9e',
          600: '#757575',
          700: '#616161',
          800: '#424242',
          900: '#212121'
        },
        // Background colors
        'back': {
          light: '#fafafa',
          dark: '#1a1a1a'
        },
        // Border colors
        'border': {
          light: '#e0e0e0',
          dark: '#333333'
        }
      },
      fontFamily: {
        'sans': ['ui-sans-serif', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
        'mono': ['ui-monospace', 'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', 'monospace'],
      },
      fontSize: {
        'xs': ['0.75rem', { lineHeight: '1rem' }],
        'sm': ['0.875rem', { lineHeight: '1.25rem' }],
        'base': ['1rem', { lineHeight: '1.5rem' }],
        'lg': ['1.125rem', { lineHeight: '1.75rem' }],
        'xl': ['1.25rem', { lineHeight: '1.75rem' }],
        '2xl': ['1.5rem', { lineHeight: '2rem' }],
        '3xl': ['1.875rem', { lineHeight: '2.25rem' }],
        '4xl': ['2.25rem', { lineHeight: '2.5rem' }],
      },
      spacing: {
        'sidebar': '280px',
        'header': '64px',
      }
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
}