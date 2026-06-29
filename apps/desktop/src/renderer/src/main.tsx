import './styles/globals.css'

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './app/App'
import { configureMonaco } from './lib/monaco'

configureMonaco()

const mode = window.location.hash === '#temp' ? 'temporary' : 'main'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App mode={mode} />
  </StrictMode>
)
