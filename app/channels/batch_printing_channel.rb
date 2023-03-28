class BatchPrintingChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'batch_printing'
  end
end
