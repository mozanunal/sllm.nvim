-- Pandoc Lua filter: only level-1 headings keep tags; others become bold text.
-- This prevents tag bloat while keeping section emphasis.

function Header(el)
  if el.level == 1 then
    return el
  end
  -- Render subheadings as bold paragraphs (no tags).
  return pandoc.Para({ pandoc.Strong(el.content) })
end
