const formatter = new Intl.RelativeTimeFormat('en', {
  numeric: 'auto'
})

export function formatRelativeTime(isoString: string): string {
  const target = new Date(isoString).getTime()
  const deltaSeconds = Math.round((target - Date.now()) / 1000)

  const ranges: Array<[Intl.RelativeTimeFormatUnit, number]> = [
    ['year', 60 * 60 * 24 * 365],
    ['month', 60 * 60 * 24 * 30],
    ['week', 60 * 60 * 24 * 7],
    ['day', 60 * 60 * 24],
    ['hour', 60 * 60],
    ['minute', 60],
    ['second', 1]
  ]

  for (const [unit, seconds] of ranges) {
    if (Math.abs(deltaSeconds) >= seconds || unit === 'second') {
      return formatter.format(Math.round(deltaSeconds / seconds), unit)
    }
  }

  return 'just now'
}
