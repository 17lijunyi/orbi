import { createFileRoute } from '@tanstack/react-router'

import { Home, homeHead } from '#/components/site/home'

export const Route = createFileRoute('/')({ head: () => homeHead('en'), component: Home })
