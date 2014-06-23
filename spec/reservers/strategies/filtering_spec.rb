require "spec_helper"

describe "Reservers::Strategies::Filtering" do
  before(:each) do
    Qmore.client.redis.flushall
    Qmore.configuration = Qmore::Configuration.new
  end

  context "default qless filtering behavior" do
    it "can filter multiple queues" do
      high_queue = Qmore.client.queues['high']
      critical_queue = Qmore.client.queues['critical']

      high_queue.put(SomeJob, {})
      critical_queue.put(SomeJob, {})

      queues = [high_queue, critical_queue]
      filter = Qmore::Reservers::Strategies::Filtering.default(queues, ["*"])

      queues = filter.collect(&:name)
      expect(queues).to include('critical')
      expect(queues).to include('high')
    end

    it "should only return matching queues" do
      high_queue = Qmore.client.queues['high']
      critical_queue = Qmore.client.queues['critical']

      high_queue.put(SomeJob, {})
      critical_queue.put(SomeJob, {})

      queues = [high_queue, critical_queue]
      filter = Qmore::Reservers::Strategies::Filtering.default(queues, ['critical'])

      queues = filter.collect(&:name)
      expect(queues).to include('critical')
      expect(queues).to_not include('high')
    end

    it "handles priorities" do
      Qmore.configuration.priority_buckets = [{'pattern' => 'foo*', 'fairly' => false},
                            {'pattern' => 'default', 'fairly' => false},
                            {'pattern' => 'bar', 'fairly' => true}]

      queues = []
      ['other', 'blah', 'foobie', 'bar', 'foo'].each do |q|
        queue = Qmore.client.queues[q]
        queue.put(SomeJob, {})
        expect(queue.length).to be(1)
        queues << queue
      end

      filter = Qmore::Reservers::Strategies::Filtering.default(queues, ['*', '!blah'])

      expect(filter.next.name).to be('foo')
      expect(filter.next.name).to be('foobie')
      expect(filter.next.name).to be('other')
      expect(filter.next.name).to be('bar')
      expect { filter.next }.to raise_error(StopIteration)
    end
  end
end
