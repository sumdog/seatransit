require 'httparty'

stops = [621, 1652]

class SeattleTransit
  include HTTParty
  base_uri 'http://api.pugetsound.onebusaway.org/api/where/arrivals-and-departures-for-stop/'

  def initialize(stop_id)
    @stop_id = stop_id
    @options = { :query => { 'key' => 'c3a97cae-0b52-40c4-adad-b1615c15f554' } }
    refresh()
  end

  def refresh()
    @json = self.class.get("/1_#{@stop_id}.json", @options)
  end

  def arrival(predicted, scheduled)
    timestamp = predicted != 0 ? predicted : scheduled
    miliseconds = timestamp - (Time.now.to_i * 1000)
    minutes = miliseconds / 1000 / 60
    case minutes
      when 0
        "now"
      else
        "%s min" % minutes
    end
  end

  def station_name()
    @json['data']['references']['stops'].each { |s|
      if s['code'] == @stop_id.to_s
        return "#{s['name']} (#{direction(s['direction'])})"
      end
    }
    return "Stop #{@stop_id}"
  end

  def direction(abr)
    case abr
      when 'N'
        'North'
      when 'S'
        'South'
      when 'E'
        'East'
      when 'W'
        'West'
      when 'NE'
        'North East'
      when 'NW'
        'North West'
      when 'SE'
        'South East'
      when 'SW'
        'South West'
      else
        abr
    end
  end

  def schedule()
    now = Time.now.to_i * 1000
    @json['data']['entry']['arrivalsAndDepartures'].map { |v|
      { :calc => arrival(v['predictedArrivalTime'].to_i, v['scheduledArrivalTime'].to_i),
	      :data => v['predictedArrivalTime'].to_i == 0 ? 'sched' : 'live',
	      :num  => v['routeShortName']
      }
    }.select { |h|
      # Remove transport that's already departed
      h unless h[:calc].start_with?('-')
    }[0..5]
  end
end


SCHEDULER.every '1m' do
  for s in stops
    client = SeattleTransit.new(s)
    send_event("seatransit_#{s}", { station: client.station_name(), schedule: client.schedule() })
  end
end
