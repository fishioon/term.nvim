-- help for terminal
local config = {
  split_cmd = 'split',
  shell = os.getenv('SHELL') or 'zsh',
  win = { height = 0, width = 0 },
}

-- keep last terminal window config
local term_last_win_config = {}

local function find_terminal_window()
  for _, id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local info = vim.fn.getwininfo(id)[1]
    if info.terminal == 1 then
      for _, chan in pairs(vim.api.nvim_list_chans()) do
        if chan.buffer == info.bufnr then
          return { winid = info.winid, bufnr = info.bufnr, chanid = chan.id, }
        end
      end
    end
  end
  return nil
end

local function fork_terminal(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local argv_name = 'echo ' .. bufname
  for _, chan in pairs(vim.api.nvim_list_chans()) do
    if chan.mode == 'terminal' and chan.argv then
      for _, item in pairs(chan.argv) do
        if item == argv_name then
          -- vim.print('find terminal ' .. chan.id)
          return { bufnr = chan.buffer, chanid = chan.id }
        end
      end
    end
  end
  return nil
end

local function find_cwd_terminal()
  local prefix = string.gsub(vim.fn.getcwd(), '^' .. os.getenv('HOME'), "term://~") .. '//'
  for _, chan in pairs(vim.api.nvim_list_chans()) do
    if chan.mode == 'terminal' then
      local name = vim.api.nvim_buf_get_name(chan.buffer)
      if name:find(prefix, 1, true) == 1 then
        return { bufnr = chan.buffer, chanid = chan.id, }
      end
    end
  end
  return nil
end

-- TODO: 优化代码
local function create_terminal_window(iscwd)
  local origin_winid = vim.api.nvim_get_current_win()
  local origin_bufnr = vim.api.nvim_get_current_buf()
  local term = fork_terminal(origin_bufnr) or (iscwd and find_cwd_terminal() or nil)
  if term == nil then
    local bufnr = vim.api.nvim_create_buf(true, true)
    term = { bufnr = bufnr, chanid = 0 }
    -- vim.api.nvim_buf_set_var(bufnr, 'parent_bufnr', origin_bufnr)
  end
  local win_config = term_last_win_config[term.bufnr] or config.win
  if win_config.pos and win_config.pos[1] < 2 then
    vim.cmd('vsplit')
    term.winid = vim.api.nvim_get_current_win()
    if win_config.width > 0 then
      vim.api.nvim_win_set_width(term.winid, win_config.width)
    end
  else
    vim.cmd('split')
    term.winid = vim.api.nvim_get_current_win()
    if win_config.height > 0 then
      vim.api.nvim_win_set_height(term.winid, win_config.height)
    end
  end
  vim.api.nvim_set_current_buf(term.bufnr)
  if term.chanid == 0 then
    local origin_name = vim.api.nvim_buf_get_name(origin_bufnr)
    term.chanid = vim.fn.termopen({ config.shell, '-C', 'echo ' .. origin_name })
  end

  vim.api.nvim_set_current_win(origin_winid)
  return term
end

local function send_to_terminal(text, active)
  local term = find_terminal_window()
  if term == nil then
    term = create_terminal_window()
  end
  vim.api.nvim_chan_send(term.chanid, text)
  if active then
    vim.api.nvim_set_current_win(term.winid)
    vim.cmd.startinsert()
  end
end

local function toggle()
  local term = find_terminal_window()
  if term == nil then
    term = create_terminal_window(true)
    vim.api.nvim_set_current_win(term.winid)
    vim.cmd.startinsert()
  else
    term_last_win_config[term.bufnr] = {
      height = vim.api.nvim_win_get_height(term.winid),
      width = vim.api.nvim_win_get_width(term.winid),
      pos = vim.api.nvim_win_get_position(term.winid),
    }
    -- vim.print(term_last_win_config)
    vim.api.nvim_win_hide(term.winid)
  end
end

local function setup(opt)
  if not opt then return end
  config = vim.tbl_extend('force', config, opt)
end

return {
  setup = setup,
  send = send_to_terminal,
  toggle = toggle,
}
