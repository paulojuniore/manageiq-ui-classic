/* eslint-disable react/no-array-index-key */
import * as React from 'react';
import PropTypes from 'prop-types';
import MiqStructuredList from '../miq-structured-list';

export default function SimpleTable(props) {
  const { rows, labels, title } = props;

  return (
    <MiqStructuredList
      headers={labels}
      rows={rows}
      title={title}
      mode="simple_table"
      onClick={() => props.onClick}
    />
  );
}

SimpleTable.propTypes = {
  title: PropTypes.string.isRequired,
  labels: PropTypes.arrayOf(PropTypes.oneOfType([
    PropTypes.string,
    PropTypes.shape({ value: PropTypes.string.isRequired, sortable: PropTypes.string }),
  ])).isRequired,
  rows: PropTypes.arrayOf(PropTypes.arrayOf(PropTypes.any)).isRequired,
  onClick: PropTypes.func.isRequired,
};
