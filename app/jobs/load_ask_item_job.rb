class LoadAskItemJob < ApplicationJob
  queue_as :default

  def perform(ask_news_location, hn_story_id)
    begin
      story_json = JSON.parse HTTP.get("https://hacker-news.firebaseio.com/v0/item/#{hn_story_id}.json?print=pretty").to_s
      if story_json.nil?
        return
      end
      item = Item.where(hn_id: hn_story_id).first_or_create
      item.populate(story_json)
      item.save

      ask_item = AskItem.where(location: ask_news_location).first_or_create
      ask_item.item = item
      ask_item.save

      ActionCable.server.broadcast "AskItemChannel:#{ask_item.location}", {
        message: AsksController.render( ask_item.item ).squish,
        location: ask_item.location
      }
      ActionCable.server.broadcast "ItemsListChannel:#{ask_item.item.id}", {
        item: ItemsController.render( ask_item.item ).squish,
        item_id: ask_item.item.id
      }
    rescue URI::InvalidURIError => error
      logger.error error
    end
  end
end
