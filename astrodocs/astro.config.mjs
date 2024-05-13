import { defineConfig } from 'astro/config'
import starlight from '@astrojs/starlight'

import robotsTxt from 'astro-robots-txt'

// https://astro.build/config
export default defineConfig({
	build: {
		inlineStylesheets: 'always'
	},
	integrations: [starlight({
		lastUpdated: true,
		title: 'Confluent Cloud Secrets Engine',
		editLink: {
			baseUrl: 'https://github.com/confluentinc/confluent-cloud-secrets-engine/edit/main/astrodocs'
		},
		logo: {
			light: '/src/assets/confluent.svg',
			dark: '/src/assets/confluent-dark.svg',
		},
		sidebar: [{
			label: 'Home',
			items: [{
				label: 'Introduction',
				link: '/'
			}]
		}, {
			label: 'Guides',
			autogenerate: {
				directory: 'guides'
			}
		},
		{
			label: 'Documentation Updates',
			autogenerate: {
				directory: 'documentation_updates'
			}
		}]
	}),
		robotsTxt({
        			policy: [{
        				userAgent: '*',
        				disallow: ['/']
        			}]
        		})
        	],
        	site: 'https://confluentinc.github.io/confluent-cloud-secrets-engine/',
	        base: '/confluent-cloud-secrets-engine'
        })
