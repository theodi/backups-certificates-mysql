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

    context 'users' do
      before :all do
        @users = @client.query 'SELECT * FROM users'
      end

      it 'has plenty users' do
        expect(@users.count).to be > 7183
      end

      it 'has the correct users' do
        expect(@users.map { |u| u['email'] }[7]).to eq 'jeni@theodi.org'
      end
    end

    context 'certificates' do
      before :all do
        @certs = @client.query 'SELECT * FROM certificates'
      end

      it 'has thousands of certificates' do
        expect(@certs.count).to be > 223465
      end

      it 'has the correct certificates' do
        expect(@certs.map { |c| c['curator'] }[40]).to eq 'Ulrich Atz'
      end
    end

    context 'datasets' do
      before :all do
        @sets = @client.query 'SELECT * FROM datasets'
      end

      it 'has thousands of datasets' do
        expect(@sets.count).to be > 210276
      end
    end
  end
end
