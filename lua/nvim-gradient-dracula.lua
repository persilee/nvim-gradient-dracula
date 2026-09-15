-- Compatibility facade so lazy.nvim's default `main` (the repo name
-- "nvim-gradient-dracula") resolves when `opts` is used without `config`.
-- The real implementation lives in the `nvimpire` module.
return require('nvimpire')
