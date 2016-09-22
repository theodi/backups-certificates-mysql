describe 'Test MySQL restore' do
  context 'Check we can restore' do
    context 'tables' do
      before :all do
        @tables = @client.query('SHOW TABLES').map { |t| t.values.first }
      end

      it 'has enough tables' do
        expect(@tables.count).to eq 27
      end

      it 'has the correct tables' do
        expect(@tables.first).to eq 'answers'
        expect(@tables.last).to eq 'verifications'
        expect(@tables).to include 'kitten_data'
      end
    end
  end
end
