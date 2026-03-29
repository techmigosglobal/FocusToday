declare module 'google-translate-api' {
  type TranslateOptions = {
    from?: string;
    to?: string;
  };

  type TranslateResult = {
    text: string;
    from?: {
      language?: {
        didYouMean?: boolean;
        iso?: string;
      };
      text?: {
        autoCorrected?: boolean;
        value?: string;
        didYouMean?: boolean;
      };
    };
    raw?: unknown;
  };

  function translate(
    text: string,
    options?: TranslateOptions,
  ): Promise<TranslateResult>;

  export = translate;
}
