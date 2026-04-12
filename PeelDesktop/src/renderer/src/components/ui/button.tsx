import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'

import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md border text-sm font-medium transition-colors outline-none focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-45 [&_svg]:pointer-events-none [&_svg]:size-4',
  {
    variants: {
      variant: {
        default:
          'border-transparent bg-[var(--foreground)] px-3 py-2 text-[var(--background)] hover:bg-[color-mix(in_srgb,var(--foreground)_85%,transparent)] focus-visible:ring-[var(--ring)]',
        outline:
          'border-[var(--border-strong)] bg-transparent px-3 py-2 text-[var(--foreground)] hover:bg-[color-mix(in_srgb,var(--foreground)_5%,transparent)] focus-visible:ring-[var(--ring)]',
        ghost:
          'border-transparent bg-transparent px-2.5 py-1.5 text-[var(--muted)] hover:bg-[color-mix(in_srgb,var(--foreground)_5%,transparent)] hover:text-[var(--foreground)] focus-visible:ring-[var(--ring)]',
        accent:
          'border-transparent bg-[var(--accent)] px-3 py-2 text-[var(--accent-foreground)] hover:bg-[color-mix(in_srgb,var(--accent)_88%,transparent)] focus-visible:ring-[var(--ring)]'
      },
      size: {
        default: 'h-8',
        sm: 'h-7 px-2.5 text-xs',
        lg: 'h-9 px-4 text-sm',
        icon: 'size-8 rounded-md',
        'icon-sm': 'size-7 rounded-md'
      }
    },
    defaultVariants: {
      variant: 'default',
      size: 'default'
    }
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, ...props }, ref) => {
    return (
      <button className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />
    )
  }
)
Button.displayName = 'Button'

export { Button }
