" Prevent double loading
if exists('g:dadview_loaded')
  finish
endif

let g:dadview_loaded = 1

" Default configuration
if !exists('g:dadview_auto_execute_table_helpers')
  let g:dadview_auto_execute_table_helpers = 1
endif

" Commands
command! -nargs=? DadView lua require('dadview').toggle(<f-args>)
command! -nargs=? DadViewToggle lua require('dadview').toggle(<f-args>)
command! -nargs=1 DadViewConnect lua require('dadview').set_connection(require('dadview').find_connection("<args>"))
command! DadViewClose lua require('dadview').close()
command! DadViewNewQuery lua require('dadview').new_query_buffer()
command! DadViewExecute lua require('dadview').execute_query_buffer()
command! DadViewCancel lua require('dadview').cancel_query()
command! DadViewFindBuffer lua require('dadview').find_buffer()
command! DadViewRenameBuffer lua require('dadview').rename_buffer()
command! DadViewLastQueryInfo lua require('dadview').last_query_info()

" DB-compatible commands for backwards compatibility (optional)
" These can be used as drop-in replacements if migrating from vim-dadbod
command! -nargs=* DB lua require('dadview').execute_query_buffer()
command! DBCancel lua require('dadview').cancel_query()

" Debug and memory leak investigation commands
command! DadViewDiagnoseNativeLeak lua require('dadview.debug_memory').diagnose_native_leak()
command! DadViewStopAllMonitoring lua require('dadview.debug_memory').stop_all_monitoring()
command! DadViewCancelAllQueries lua local db = require('dadview.db'); print(string.format("Cancelled %d queries", db.cancel_all_queries()))
command! DadViewCheckUndoHistory lua require('dadview').check_undo_history()
command! DadViewClearUndoHistory lua require('dadview').clear_undo_history()
