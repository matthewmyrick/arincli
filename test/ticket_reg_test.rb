# Copyright (C) 2011,2012 American Registry for Internet Numbers
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
# IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


require 'test/unit'
require 'ticket_reg'
require 'rexml/document'
require 'tmpdir'
require 'fileutils'

class TicketRegTest < Test::Unit::TestCase

  @workd_dir = nil

  def setup

    @work_dir = Dir.mktmpdir

  end

  def teardown

    FileUtils.rm_r( @work_dir )

  end

  def test_ticket_summary

    file = File.new( File.join( File.dirname( __FILE__ ) , "ticket-summary.xml" ), "r" )
    doc = REXML::Document.new( file )
    element = doc.root

    ticket = ARINr::Registration::element_to_ticket element
    assert_equal( "20121012-X1", ticket.ticket_no )
    assert_equal( "2012-10-12T11:39:36.724-04:00", ticket.created_date )
    assert_equal( "2012-10-12T11:39:36.724-04:00", ticket.updated_date )
    assert_equal( "PENDING_REVIEW", ticket.ticket_status )
    assert_equal( "QUESTION", ticket.ticket_type )

    element = ARINr::Registration::ticket_to_element ticket
    ticket = ARINr::Registration::element_to_ticket element
    assert_equal( "20121012-X1", ticket.ticket_no )
    assert_equal( "2012-10-12T11:39:36.724-04:00", ticket.created_date )
    assert_equal( "2012-10-12T11:39:36.724-04:00", ticket.updated_date )
    assert_equal( "PENDING_REVIEW", ticket.ticket_status )
    assert_equal( "QUESTION", ticket.ticket_type )

  end

  def test_ticket_message
    file = File.new( File.join( File.dirname( __FILE__ ) , "ticket_message.xml" ), "r" )
    doc = REXML::Document.new( file )
    element = doc.root

    message = ARINr::Registration::element_to_ticket_message element
    assert_equal( "NONE", message.category )
    assert_equal( "4", message.id )
    assert_equal( "2012-10-12T11:48:50.281-04:00", message.created_date )
    assert_equal( 2, message.text.size )
    assert_equal( "pleasee get back to me", message.text[0] )
    assert_equal( "you bone heads", message.text[1] )
    assert_equal( 1, message.attachments.size )
    assert_equal( "oracle-driver-license.txt", message.attachments[0].file_name )
    assert_equal( "8a8180b13a5597b1013a55a9d42f0007", message.attachments[0].id )

    element = ARINr::Registration::ticket_message_to_element message
    message = ARINr::Registration::element_to_ticket_message element
    assert_equal( "NONE", message.category )
    assert_equal( "4", message.id )
    assert_equal( "2012-10-12T11:48:50.281-04:00", message.created_date )
    assert_equal( 2, message.text.size )
    assert_equal( "pleasee get back to me", message.text[0] )
    assert_equal( "you bone heads", message.text[1] )
    assert_equal( 1, message.attachments.size )
    assert_equal( "oracle-driver-license.txt", message.attachments[0].file_name )
    assert_equal( "8a8180b13a5597b1013a55a9d42f0007", message.attachments[0].id )
  end

  def test_store_ticket_summary

    dir = File.join( @work_dir, "test_store_ticket_summary" )
    c = ARINr::Config.new( dir )
    c.logger.message_level = "NONE"
    c.setup_workspace

    mgr = ARINr::Registration::TicketStorageManager.new c

    ticket = ARINr::Registration::Ticket.new
    ticket.ticket_no="XB85"
    ticket.created_date="July 18, 2011"
    ticket.resolved_date="July 19, 2011"
    ticket.closed_date="July 20, 2011"
    ticket.updated_date="July 21, 2011"
    ticket.ticket_type="QUESTION"
    ticket.ticket_status="APPROVED"
    ticket.ticket_resolution="DENIED"

    mgr.put_ticket ticket, ARINr::Registration::TicketStorageManager::SUMMARY_FILE_SUFFIX

    ticket2 = mgr.get_ticket "XB85", ARINr::Registration::TicketStorageManager::SUMMARY_FILE_SUFFIX

    assert_equal( "XB85", ticket2.ticket_no )
    assert_equal( "July 18, 2011", ticket2.created_date )
    assert_equal( "July 19, 2011", ticket2.resolved_date )
    assert_equal( "July 20, 2011", ticket2.closed_date )
    assert_equal( "July 21, 2011", ticket2.updated_date )
    assert_equal( "QUESTION", ticket2.ticket_type )
    assert_equal( "APPROVED", ticket2.ticket_status )
    assert_equal( "DENIED", ticket2.ticket_resolution )

  end

  def test_store_ticket_message

    dir = File.join( @work_dir, "test_store_ticket_summary" )
    c = ARINr::Config.new( dir )
    c.logger.message_level = "NONE"
    c.setup_workspace

    mgr = ARINr::Registration::TicketStorageManager.new c
    message = ARINr::Registration::TicketMessage.new
    message.subject="Test"
    message.text=[ "This is line 1", "This is line 2" ]
    message.category="NONE"
    message.id="4"

    mgr.put_ticket_message "XB85", message
  end

end