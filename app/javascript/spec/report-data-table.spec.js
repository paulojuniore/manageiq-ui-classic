import React from 'react';
import { mount } from 'enzyme';
import fetchMock from 'fetch-mock';
import { act } from 'react-dom/test-utils';

import './helpers/mockAsyncRequest';
import './helpers/miqSparkle';

import ReportDataTable from '../components/data-tables/report-data-table/report-data-table';

describe('<ReportDataTable />', () => {
  let initialProps;
  jest.setTimeout(30000);

  beforeEach(() => {
    initialProps = {
      reportResultId: 123,
      perPageDefault: 20,
      perPageOptions: [20, 50, 100],
      reportType: 'data',
    };
  });

  afterEach(() => {
    fetchMock.reset();
  });

  const requestUrl = () => {
    const sortBy = '';
    const sortDirection = '';
    const limit = 20;
    const offset = 0;
    return `/api/results/${initialProps.reportResultId}?\
expand_value_format=true&\
hash_attribute=result_set&\
sort_by=${sortBy}&sort_order=${sortDirection}&\
limit=${limit}&offset=${offset}`;
  };

  it('should fetch and display report data when instantiated', async(done) => {
    fetchMock.getOnce(requestUrl(), { report: { col_order: [] }, count: 1, result_set: [{ foo: 'bar' }] });
    let wrapper;
    await act(async() => {
      wrapper = mount(<ReportDataTable {...initialProps} />);
    });
    wrapper.update();
    expect(fetchMock.calls()).toHaveLength(1);
    expect(wrapper.find('div.report-table-toolbar')).toHaveLength(1);
    expect(wrapper.find('div.report-data-table')).toHaveLength(1);
    expect(wrapper.find('div.miq-pagination')).toHaveLength(1);
    done();
  });

  it('should display empty state when there is no data', async(done) => {
    fetchMock.getOnce(requestUrl(), { report: { col_order: [] }, count: 0, result_set: [] });

    let wrapper;
    await act(async() => {
      wrapper = mount(<ReportDataTable {...initialProps} />);
    });

    wrapper.update();

    expect(fetchMock.calls()).toHaveLength(1);
    expect(wrapper.find('div.report-table-toolbar')).toHaveLength(1);
    expect(wrapper.find('div.report-data-table')).toHaveLength(0);
    expect(wrapper.find('div.miq-pagination')).toHaveLength(0);
    expect(wrapper.find('div.no-records-found')).toHaveLength(1);
    done();
  });
});
