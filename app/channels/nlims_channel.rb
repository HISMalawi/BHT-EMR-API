class NlimsChannel < ApplicationCable::Channel
  def subscribed
    # ActionCable.server.broadcast("nlims_channel", {body: "This is a broadcast", status: "OK", time: Time.now})
    # stream_from "some_channel"
    stream_from 'nlims_channel'
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def results(data)
    ActionCable.server.broadcast 'nlims_channel', data
  end
end
