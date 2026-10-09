# Temporarily replaces a class method for the length of a block (newer
# Minitest has no `stub`). Give a value to return, or a proc to run.
#
#   swap_method(DatabaseBackup, :due?, true) { DatabaseBackupJob.perform_now }
module SwapMethodHelper
  def swap_method(object, name, replacement)
    original = object.method(name)
    body = replacement.is_a?(Proc) ? replacement : proc { |*| replacement }
    object.define_singleton_method(name) { |*args, **kwargs| body.call(*args, **kwargs) }
    yield
  ensure
    object.define_singleton_method(name, original)
  end
end

ActiveSupport.on_load(:active_support_test_case) { include SwapMethodHelper }
