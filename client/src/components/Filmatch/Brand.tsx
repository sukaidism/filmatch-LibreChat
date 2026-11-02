import type { TStartupConfig } from 'librechat-data-provider';
import { useLocalize } from '~/hooks';

/** Branding is deployment identity, independent of the selected colour theme. */
export const isFilmatch = (config?: Pick<TStartupConfig, 'appTitle'> | null) =>
  config?.appTitle === 'Filmatch';

export default function Brand() {
  const localize = useLocalize();
  return (
    <span className="text-accent-primary text-2xl font-semibold tracking-tight">
      {localize('com_ui_filmatch_name')}
    </span>
  );
}

export function Credits() {
  const localize = useLocalize();
  return (
    <div className="text-text-secondary flex flex-wrap items-center justify-center gap-x-1 px-6 py-4 text-center text-xs leading-relaxed">
      <span>{localize('com_ui_filmatch_demo')}</span>
      <span>{localize('com_ui_filmatch_powered')}</span>
      <a
        className="focus-visible:outline-focus-control rounded-sm underline underline-offset-4 focus-visible:outline focus-visible:outline-2"
        href="https://www.librechat.ai"
        target="_blank"
        rel="noreferrer"
      >
        {localize('com_ui_filmatch_credits')}
      </a>
    </div>
  );
}
