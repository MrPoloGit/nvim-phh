-- Filetype detection for .phh/.phhs.
-- Both extensions map to the same filetype, matching tree-sitter-phh's
-- own handling of .phhs as "just more of the same grammar, zero or more
-- arbitrary-keyed tables" (see that grammar's file header: the [N]
-- numbering is a PokerKit write-side convention, not something the
-- reader, or this filetype mapping, needs to care about).
vim.filetype.add({
  extension = {
    phh = "phh",
    phhs = "phh",
  },
})
