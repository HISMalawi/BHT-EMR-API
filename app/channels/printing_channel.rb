class PrintingChannel < ApplicationCable::Channel
  def subscribed
    stream_from "printing_channel"
  end

  def send_text data
    ActionCable.server.broadcast printing_channel, data
  end
end
